/*
 * Guillaume Cottenceau (gc@mandrakesoft.com)
 *
 * Copyright 2000 MandrakeSoft
 *
 * This software may be freely redistributed under the terms of the GNU
 * public license.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/*
 * Portions from Erik Troan (ewt@redhat.com)
 *
 * Copyright 1996 Red Hat Software 
 *
 */

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "log.h"
#include "modules.h"

#include "mount.h"


/* WARNING: this won't work if the argument is not /dev/ based */
static int ensure_dev_exists(char *dev)
{
	int major, minor;
	int type = S_IFBLK; /* my default type is block. don't forget to change for chars */
	char * name;
	struct stat buf;
	
	name = &dev[5]; /* we really need that dev be passed as /dev/something.. */

	if (!stat(dev, &buf))
		return 0; /* if the file already exists, we assume it's correct */

	if (name[0] == 's' && name[1] == 'd') {
		/* SCSI disks */
		major = 8;
		minor = (name[2] - 'a') << 4;
		if (name[3] && name[4])
			minor += 10 + (name[4] - '0');
		else if (name[3])
			minor += (name[3] - '0');
	} else if (name[0] == 'h' && name[1] == 'd') {
		/* IDE disks/cd's */
		if (name[2] == 'a')
			major = 3, minor = 0;
		else if (name[2] == 'b')
			major = 3, minor = 64;
		else if (name[2] == 'c')
			major = 22, minor = 0;
		else if (name[2] == 'd')
			major = 22, minor = 64;
		else if (name[2] == 'e')
			major = 33, minor = 0;
		else if (name[2] == 'f')
			major = 33, minor = 64;
		else if (name[2] == 'g')
			major = 34, minor = 0;
		else if (name[2] == 'h')
			major = 34, minor = 64;
		else
			return -1;
		
		if (name[3] && name[4])
			minor += 10 + (name[4] - '0');
		else if (name[3])
			minor += (name[3] - '0');
	} else if (name[0] == 's' && name[1] == 'c' && name[2] == 'd') {
		/* SCSI cd's */
		major = 11;
		minor = name[3] - '0';
	} else {
		log_message("I don't know how to create device %s, please post bugreport to me!", dev);
		return -1;
	}

	if (mknod(dev, type | 0600, makedev(major, minor))) {
		log_perror(dev);
		return -1;
	}
	
	return 0;
}


/* mounts, creating the device if needed+possible */
int my_mount(char *dev, char *location, char *fs)
{
	unsigned long flags;
	char * opts = NULL;
	struct stat buf;
	int rc;

	rc = ensure_dev_exists(dev);

	if (rc != 0) {
		log_message("could not create required device file");
		return -1;
	}

	log_message("mounting %s on %s as type %s", dev, location, fs);

	if (stat(location, &buf)) {
		if (mkdir(location, 0755)) {
			log_message("could not create location dir");
			return -1;
		}
	} else if (!S_ISDIR(buf.st_mode)) {
		log_message("not a dir %s, will unlink and mkdir", location);
		if (unlink(location)) {
			log_message("could not unlink %s", location);
			return -1;
		}
		if (mkdir(location, 0755)) {
			log_message("could not create location dir");
			return -1;
		}
	}

	flags = MS_MGC_VAL;

	if (!strcmp(fs, "vfat")) {
		my_insmod("vfat");
		opts = "check=relaxed";
	}

	if (!strcmp(fs, "iso9660")) {
		my_insmod("isofs");
		flags |= MS_RDONLY;
	}

	rc = mount(dev, location, fs, flags, opts);

	if (rc != 0)
		log_perror(dev);

	return rc;
}
