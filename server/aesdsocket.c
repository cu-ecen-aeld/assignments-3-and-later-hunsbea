#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <signal.h>
#include <arpa/inet.h>
#include <fcntl.h>

#define PORT 9000
#define INITIAL_BUF_SIZE 128
#define FILE_PATH "/var/tmp/aesdsocketdata"

int sock_fd = -1;
int client_sock = -1;
int file_fd = -1;
int opt = 1;
char *buffer = NULL;
size_t max_buffer_size = INITIAL_BUF_SIZE;

void handle_signal(int sig) {
    syslog(LOG_INFO, "Caught signal %d, exiting gracefully", sig);
    if (client_sock != -1) close(client_sock);
    if (sock_fd != -1) close(sock_fd);
    if (file_fd != -1) close(file_fd);
    if (buffer) free(buffer);
    remove(FILE_PATH);
    exit(0);
}

void setup_signal_handling() {
    struct sigaction sa;
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
}

int main(int argc, char *argv[]) {
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);

    setup_signal_handling();
    openlog("aesdsocket", LOG_PID, LOG_USER);

    sock_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_fd < 0) {
        syslog(LOG_ERR, "Failed to create socket");
        return -1;
    }

    if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt))) {
        syslog(LOG_ERR, "Failed to set socket opt");
        return -1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(PORT);
    if (bind(sock_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        syslog(LOG_ERR, "Failed to bind socket");
        return -1;
    }

    if (listen(sock_fd, 5) < 0) {
        syslog(LOG_ERR, "Failed to listen on socket");
        return -1;
    }

    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        pid_t pid = fork();
        if (pid < 0) {
            syslog(LOG_ERR, "Fork failed");
            return -1;
        }
        if (pid > 0) {
            return 0;
        }
        setsid();
        chdir("/");
        close(STDIN_FILENO);
        close(STDOUT_FILENO);
        close(STDERR_FILENO);
    }

    buffer = malloc(INITIAL_BUF_SIZE);
    if (!buffer) {
        syslog(LOG_ERR, "Failed to allocate buffer");
        return -1;
    }

    while (1) {
        client_sock = accept(sock_fd, (struct sockaddr *)&client_addr, &client_len);
        if (client_sock < 0) {
            syslog(LOG_ERR, "Failed to accept connection");
            continue;
        }

        syslog(LOG_INFO, "Accepted connection from %s", inet_ntoa(client_addr.sin_addr));

        file_fd = open(FILE_PATH, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (file_fd < 0) {
            syslog(LOG_ERR, "Failed to open file");
            close(client_sock);
            continue;
        }

        size_t received, total_received = 0;
        char *temp_buffer;
        int newline_found;

        do {
            received = recv(client_sock, buffer + total_received, max_buffer_size - total_received, 0);
            if (received <= 0) {
                break;
            }

            total_received += received;
            newline_found = 0;

            for (size_t i = 0; i < total_received; i++) {
                if (buffer[i] == '\n') {
                    newline_found = 1;
                    break;
                }
            }

            if (!newline_found && total_received == max_buffer_size) {
                max_buffer_size *= 2;
                temp_buffer = realloc(buffer, max_buffer_size);
                if (!temp_buffer) {
                    syslog(LOG_ERR, "Failed to realloc buffer");
                    close(file_fd);
                    close(client_sock);
                    free(buffer);
                    return -1;
                }
                buffer = temp_buffer;
            }
        } while (!newline_found);

        write(file_fd, buffer, total_received);
        close(file_fd);

        file_fd = open(FILE_PATH, O_RDONLY);
        if (file_fd < 0) {
            syslog(LOG_ERR, "Failed to open file for reading");
            close(client_sock);
            continue;
        }

        ssize_t read_bytes;
        off_t offset = 0;
        while ((read_bytes = pread(file_fd, buffer, max_buffer_size, offset)) > 0) {
            send(client_sock, buffer, read_bytes, 0);
            offset += read_bytes;
        }
        close(file_fd);

        syslog(LOG_INFO, "Connection closed from %s", inet_ntoa(client_addr.sin_addr));
        close(client_sock);
        client_sock = -1;
    }

    if (buffer) free(buffer);
    if (sock_fd != -1) close(sock_fd);
    remove(FILE_PATH);
    closelog();

    return 0;
}
