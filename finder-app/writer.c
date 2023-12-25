#include <stdio.h>
#include <syslog.h>

int main(int argc, char *argv[]) {
	openlog("writer", LOG_PID, LOG_USER);

	if (argc != 3) {
		syslog(LOG_ERR, "Usage: %s <filepath> <content>", argv[0]);
		closelog();
		return 1;
	}

	const char *fpath = argv[1];
	const char *s = argv[2];
	syslog(LOG_DEBUG, "Writing '%s' to '%s'", s, fpath);

	FILE *fp = fopen(fpath, "w");
	if (fp == NULL) {
		syslog(LOG_ERR, "Failed to open file: '%s'", fpath);
		closelog();
		return 1;
	}

	if (fputs(s, fp) == EOF) {
		syslog(LOG_ERR, "Failed to write to file: '%s'", fpath);
		fclose(fp);
		closelog();
		return 1;
	}

	fclose(fp);
	closelog();
	return 0;
}
