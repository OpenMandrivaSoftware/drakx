/*
 * Guillaume Cottenceau (gc@mandriva.com)
 *
 * Copyright 2000 Mandriva
 *
 * This software may be freely redistributed under the terms of the GNU
 * public license.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/utsname.h>

#include "utils.h"
#include "log.h"

// warning, many things rely on the fact that:
// - when failing it returns 0
// - it stops on first non-digit char
int charstar_to_int(const char * s)
{
	int number = 0;
	while (*s && isdigit(*s)) {
		number = (number * 10) + (*s - '0');
		s++;
	}
	return number;
}

off_t file_size(const char * path)
{
	struct stat statr;
	if (stat(path, &statr))
		return -1;
        else
                return statr.st_size;
}

char * cat_file(const char * file, struct stat * s) {
	char * buf;
	int fd = open(file, O_RDONLY);
	if (fd == -1) {
		log_perror(file);
		return NULL;
	}
	
	fstat(fd, s);
	buf = (char*)malloc(s->st_size + 1);
	if (read(fd, buf, s->st_size) != (ssize_t)s->st_size) {
		close(fd);
		free(buf);
		log_perror(file);
		return NULL;
	}
	buf[s->st_size] = '\0';
	close(fd);

	return buf;
}

int line_counts(const char * buf) {
	const char * ptr = buf;
	int line = 0;
	while (ptr) {
		line++;
		ptr = strchr(ptr + 1, '\n');
	}
	return line;
}

int total_memory(void)
{
	int value;

	/* drakx powered: use /proc/kcore and rounds every 4 Mbytes */
	value = 4 * ((int)((float)file_size("/proc/kcore") / 1024 / 1024 / 4 + 0.5));
	log_message("Total Memory: %d Mbytes", value);

	return value;
}

/* pixel's */
void * _memdup(const void *src, size_t size)
{
	void * r;
	r = malloc(size);
	memcpy(r, src, size);
	return r;
}

void add_to_env(const char * name, const char * value)
{
        FILE* fakeenv = fopen("/tmp/env", "a");
        if (fakeenv) {
                char* e = NULL;
		asprintf(&e, "%s=%s\n", name, value);
                fwrite(e, 1, strlen(e), fakeenv);
                free(e);
                fclose(fakeenv);
        } else 
                log_message("couldn't fopen to fake env");
}

char ** list_directory(const char * direct)
{
	char * tmp[50000]; /* in /dev there can be many many files.. */
	int i = 0;
	struct dirent *ep;
	DIR *dp = opendir(direct);
	while (dp && (ep = readdir(dp))) {
		if (strcmp(ep->d_name, ".") && strcmp(ep->d_name, "..")) {
			tmp[i] = strdup(ep->d_name);
			i++;
		}
	}
	if (dp)
		closedir(dp);
	tmp[i] = NULL;
	return (char**)_memdup(tmp, sizeof(char*) * (i+1));
}

int string_array_length(const char ** a)
{
	int i = 0;
	if (!a)
		return -1;
	while (a && *a) {
		a++;
		i++;
	}
	return i;
}

int scall_(int retval, char * msg, char * file, int line)
{
	char tmp[5000];
        sprintf(tmp, "%s(%s:%d) failed", msg, file, line);
        if (retval)
                log_perror(tmp);
        return retval;
}

void lowercase(char *s)
{
       int i = 0;
       while (s[i]) {
               s[i] = tolower(s[i]);
               i++;
       }
}

char *my_dirname(const char *path) {
	const char *p = strrchr (path, '/');
	char *tmp;
	int len;
	if (!p)
		return strdup(path);
	len = p-path+1;
	tmp = (char*)malloc(len);
	strncpy(tmp, path, len-1);
	tmp[len-1] = '\0';
	return tmp;
}

