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

/*
 * This is supposed to replace the redhat "kickstart", by name but
 * also by design (less code pollution).
 *
 */


#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "tools.h"
#include "utils.h"
#include "stage1.h"
#include "frontend.h"
#include "log.h"

#include "automatic.h"


static struct param_elem * automatic_params;
static const char * value_not_bound = "";

void grab_automatic_params(const char * line)
{
	int i, p;
	struct param_elem tmp_params[50];

	i = 0; p = 0;
	while (line[i] != '\0') {
		char *name, *value;
		int k;
		int j = i;
		while (line[i] != ':' && line[i] != '\0')
			i++;
		name = (char*)_memdup(&line[j], i-j + 1);
		name[i-j] = 0;

		k = i+1;
		i++;
		while (line[i] != ',' && line[i] != '\0')
			i++;
		value = (char*)_memdup(&line[k], i-k + 1);
		value[i-k] = 0;

		tmp_params[p].name = name;
		tmp_params[p].value = value;
		p++;
		if (line[i] == '\0')
			break;
		i++;
	}

	tmp_params[p++].name = NULL;
	automatic_params = (param_elem*)_memdup(tmp_params, sizeof(struct param_elem) * p);

	log_message("AUTOMATIC MODE: got %d params", p-1);
}


const char * get_auto_value(const char * auto_param)
{
	struct param_elem * ptr = automatic_params;

	struct param_elem short_aliases[] =
		{ { "method", "met" }, { "network", "netw" }, { "interface", "int" }, { "gateway", "gat" },
		  { "netmask", "netm" }, { "adsluser", "adslu" }, { "adslpass", "adslp" }, { "hostname", "hos" },
		  { "domain", "dom" }, { "server", "ser" }, { "directory", "dir" }, { "user", "use" },
		  { "pass", "pas" }, { "disk", "dis" }, { "partition", "par" }, { "proxy_host", "proxh" },
		  { "proxy_port", "proxp" }, { NULL, NULL } };
	struct param_elem * ptr_alias = short_aliases;
	while (ptr_alias->name) {
		if (streq(auto_param, ptr_alias->name))
			break;
		ptr_alias++;
	}

	while (ptr->name) {
		if (streq(ptr->name, auto_param)
		    || (ptr_alias->name && streq(ptr_alias->value, ptr->name)))
			return ptr->value;
		ptr++;
	}

	return value_not_bound;
}


enum return_type ask_from_list_auto(const char *msg, const char ** elems, char ** choice, const char * auto_param, const char ** elems_auto)
{
	if (!IS_AUTOMATIC) {
#ifdef ENABLE_BOOTSPLASH
		if (binary_name && (!strcmp(binary_name, "stage1") || !strcmp(binary_name, "rescue-gui")))
		    exit_bootsplash();
#endif
		return ask_from_list(msg, elems, choice);
	} else {
		const char ** sav_elems = elems;
		const char * tmp = get_auto_value(auto_param);
		while (elems && *elems) {
			if (!strcmp(tmp, *elems_auto)) {
				*choice = (char*)*elems;
				log_message("AUTOMATIC: parameter %s for %s means returning %s", tmp, auto_param, *elems);
				return RETURN_OK;
			}
			elems++;
			elems_auto++;
		}
		unset_automatic(); /* we are in a fallback mode */
		return ask_from_list(msg, sav_elems, choice);
	}
}

enum return_type ask_from_list_comments_auto(const char *msg, const char ** elems, const char ** elems_comments, char ** choice, const char * auto_param, const char ** elems_auto)
{
	if (!IS_AUTOMATIC) {
#ifdef ENABLE_BOOTSPLASH
		if (binary_name && (!strcmp(binary_name, "stage1") || !strcmp(binary_name, "rescue-gui")))
		    exit_bootsplash();
#endif
		return ask_from_list_comments(msg, elems, elems_comments, choice);
	} else {
		const char ** sav_elems = elems;
		const char * tmp = get_auto_value(auto_param);
		while (elems && *elems) {
			if (!strcmp(tmp, *elems_auto)) {
				*choice = (char*)*elems;
				log_message("AUTOMATIC: parameter %s for %s means returning %s", tmp, auto_param, *elems);
				return RETURN_OK;
			}
			elems++;
			elems_auto++;
		}
		unset_automatic(); /* we are in a fallback mode */
		return ask_from_list_comments(msg, sav_elems, elems_comments, choice);
	}
}


enum return_type ask_from_entries_auto(const char *msg, const char ** questions, char *** answers, int entry_size, const char ** questions_auto, void (*callback_func)(char ** strings))
{
	if (!IS_AUTOMATIC) {
#ifdef ENABLE_BOOTSPLASH
		if (binary_name && (!strcmp(binary_name, "stage1") || !strcmp(binary_name, "rescue-gui")))
    		    exit_bootsplash();
#endif
		return ask_from_entries(msg, questions, answers, entry_size, callback_func);
	} else {
		const char * tmp_answers[50];
		int i = 0;
		while (questions && *questions) {
			tmp_answers[i] = get_auto_value(*questions_auto);
			log_message("AUTOMATIC: question %s answers %s because of param %s", *questions, tmp_answers[i], *questions_auto);
			i++;
			questions++;
			questions_auto++;
			
		}
		*answers = (char**)_memdup(tmp_answers, sizeof(char *) * i);
		return RETURN_OK;
	}
}
