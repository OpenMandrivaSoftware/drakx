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


/*
 * This contains stuff related to probing:
 * (1) PCI devices
 * (2) IDE media
 * (3) SCSI media
 */


#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "log.h"
#include "frontend.h"
#include "modules.h"
#include "pci-resource/pci-ids.h"

#include "probing.h"


void pci_probing(enum driver_type type)
{
	if (IS_EXPERT)
		ask_insmod(type);
	else {
		/* do it automatically */
		char * mytype;
		FILE * f;
		int len;
		char buf[100];
		struct pci_module_map * pcidb;

		if (type == SCSI_ADAPTERS)
			mytype = "SCSI";
		else if (type == NETWORK_DEVICES)
			mytype = "NET";
		else
			return;
		
		f = fopen("/proc/bus/pci/devices", "rb");
    
		if (!f) {
			log_message("PCI: could not open proc file");
			return;
		}

		switch (type) {
		case SCSI_ADAPTERS:
			pcidb = scsi_pci_ids;
			len   = scsi_num_ids;
			break;
		case NETWORK_DEVICES:
			pcidb = eth_pci_ids;
			len   = eth_num_ids;
			break;
		default:
			return;
		}

		while (1) {
			int i, garb, vendor, device;
		
			if (!fgets(buf,100,f)) break;
		
			sscanf(buf, "%x %04x%04x", &garb, &vendor, &device);
 
			for (i = 0; i < len; i++) {
				if (pcidb[i].vendor == vendor && pcidb[i].device == device) {
					log_message("PCI: found suggestion for %s (%s)", pcidb[i].name, pcidb[i].module);
					if (type == SCSI_ADAPTERS) {
						/* insmod takes time, let's use the wait message */
						wait_message("Installing %s driver for %s", mytype, pcidb[i].name);
						my_insmod(pcidb[i].module);
						remove_wait_message();
					} else if (type == NETWORK_DEVICES) {
						/* insmod is quick, let's use the info message */
						info_message("Found %s driver for %s", mytype, pcidb[i].name);
						my_insmod(pcidb[i].module);
					}
				}
			}
		}
	}
}


static struct media_info * medias = NULL;

static void find_media(void)
{
    	char b[50];
	char buf[500];
	struct media_info tmp[50];
	int count;
        int fd;

	if (!medias)
		pci_probing(SCSI_ADAPTERS);
	else
		free(medias); /* that does not free the strings, by the way */

	/* ----------------------------------------------- */
	log_message("looking for ide media");

    	count = 0;
    	strcpy(b, "/proc/ide/hda");
    	for (; b[12] <= 'm'; b[12]++) {
		int i;
		
		/* first, test if file exists (will tell if attached medium exists) */
		b[13] = '\0';
		if (access(b, R_OK))
			continue;

		tmp[count].name = strdup("hda");
		tmp[count].name[2] = b[12];

		/* media type */
		strcpy(b + 13, "/media");
		fd = open(b, O_RDONLY);
		if (fd == -1) {
			log_message("failed to open %s for reading", b);
			continue;
		}

		i = read(fd, buf, sizeof(buf));
		if (i == -1) {
			log_message("failed to read %s", b);
			continue;
		}
		buf[i] = '\0';
		close(fd);

		if (!strncmp(buf, "disk", strlen("disk")))
			tmp[count].type = DISK;
		else if (!strncmp(buf, "cdrom", strlen("cdrom")))
			tmp[count].type = CDROM;
		else if (!strncmp(buf, "tape", strlen("tape")))
			tmp[count].type = TAPE;
		else if (!strncmp(buf, "floppy", strlen("floppy")))
			tmp[count].type = FLOPPY;
		else
			tmp[count].type = UNKNOWN_MEDIA;

		/* media model */
		strcpy(b + 13, "/model");
		fd = open(b, O_RDONLY);
		if (fd == -1) {
			log_message("failed to open %s for reading", b);
			continue;
		}

		i = read(fd, buf, sizeof(buf));
		if (i <= 0) {
			log_message("failed to read %s", b);
			tmp[count].model = strdup("(none)");
		}
		else {
			buf[i-1] = '\0'; /* eat the \n */
			tmp[count].model = strdup(buf);
		}

		log_message("IDE/%d: %s is a %s", tmp[count].type, tmp[count].name, tmp[count].model);
		tmp[count].bus = IDE;
		count++;
    	}



	/* ----------------------------------------------- */
	log_message("looking for scsi media");


	fd = open("/proc/scsi/scsi", O_RDONLY);
	if (fd != -1) {
		enum { SCSI_TOP, SCSI_HOST, SCSI_VENDOR, SCSI_TYPE } state = SCSI_TOP;
		char * start, * chptr, * next, * end;

		int i = read(fd, &buf, sizeof(buf));
		if (i < 1) {
			close(fd);
			goto end_scsi;
		}
		close(fd);
		buf[i] = '\0';

		if (!strncmp(buf, "Attached devices: none", strlen("Attached devices: none")))
			goto end_scsi;
		
		start = buf;
		while (*start) {
			char tmp_model[50];
			char tmp_name[10];
			char scsi_disk_count = 'a';
			char scsi_cdrom_count = '0';
			char scsi_tape_count = '0';

			chptr = start;
			while (*chptr != '\n') chptr++;
			*chptr = '\0';
			next = chptr + 1;
			
			switch (state) {
			case SCSI_TOP:
				if (strncmp(start, "Attached devices: ", strlen("Attached devices: ")))
					goto end_scsi;
				state = SCSI_HOST;
				break;

			case SCSI_HOST:
				if (strncmp(start, "Host: ", strlen("Host: ")))
					goto end_scsi;
				state = SCSI_VENDOR;
				break;

			case SCSI_VENDOR:
				if (strncmp(start, "  Vendor: ", strlen("  Vendor: ")))
					goto end_scsi;

				/* (1) Grab Vendor info */
				start += 10;
				end = chptr = strstr(start, "Model:");
				if (!chptr)
					goto end_scsi;

				chptr--;
				while (*chptr == ' ')
					chptr--;
				if (*chptr == ':') {
					chptr++;
					*(chptr + 1) = '\0';
					strcpy(tmp_model,"(unknown)");
				} else {
					*(chptr + 1) = '\0';
					strcpy(tmp_model, start);
				}

				/* (2) Grab Model info */
				start = end;
				start += 7;
				
				chptr = strstr(start, "Rev:");
				if (!chptr)
					goto end_scsi;
				
				chptr--;
				while (*chptr == ' ') chptr--;
				*(chptr + 1) = '\0';
				
				strcat(tmp_model, " ");
				strcat(tmp_model, start);

				tmp[count].model = strdup(tmp_model);
				
				state = SCSI_TYPE;

				break;

			case SCSI_TYPE:
				if (strncmp("  Type:", start, 7))
					goto end_scsi;
				*tmp_name = '\0';

				if (strstr(start, "Direct-Access")) {
					sprintf(tmp_name, "sd%c", scsi_disk_count++);
					tmp[count].type = DISK;
				} else if (strstr(start, "Sequential-Access")) {
					sprintf(tmp_name, "st%c", scsi_tape_count++);
					tmp[count].type = TAPE;
				} else if (strstr(start, "CD-ROM")) {
					sprintf(tmp_name, "scd%c", scsi_cdrom_count++);
					tmp[count].type = CDROM;
				}

				if (*tmp_name) {
					tmp[count].name = strdup(tmp_name);
					log_message("SCSI/%d: %s is a %s", tmp[count].type, tmp[count].name, tmp[count].model);
					tmp[count].bus = SCSI;
					count++;
				}
				
				state = SCSI_HOST;
			}
			
			start = next;
		}
		
	end_scsi:
	}

    
	/* ----------------------------------------------- */
	tmp[count].name = NULL;
	count++;

	medias = (struct media_info *) malloc(sizeof(struct media_info) * count);
	memcpy(medias, tmp, sizeof(struct media_info) * count);
}


/* Finds by media */
void get_medias(enum media_type media, char *** names, char *** models)
{
	struct media_info * m;
	char * tmp_names[50];
	char * tmp_models[50];
	int count;

	find_media();

	m = medias;

	count = 0;
	while (m && m->name) {
		if (m->type == media) {
			tmp_names[count] = strdup(m->name);
			tmp_models[count++] = strdup(m->model);
		}
		m++;
	}
	tmp_names[count] = NULL;
	tmp_models[count++] = NULL;

	*names = (char **) malloc(sizeof(char *) * count);
	memcpy(*names, tmp_names, sizeof(char *) * count);

	*models = (char **) malloc(sizeof(char *) * count);
	memcpy(*models, tmp_models, sizeof(char *) * count);
}
