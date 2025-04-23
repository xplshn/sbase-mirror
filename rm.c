/* See LICENSE file for copyright and license details. */
#include <fcntl.h>

#include "fs.h"
#include "util.h"

static void
usage(void)
{
	eprintf("usage: %s [-f] [-iRr] file ...\n", argv0);
}

int
main(int argc, char *argv[])
{
	struct recursor r = { .fn = rm, .maxdepth = 1, .follow = 'P' };

	ARGBEGIN {
	case 'f':
		r.flags |= SILENT | IGNORE;
		break;
	case 'i':
		r.flags |= CONFIRM;
		break;
	case 'R':
	case 'r':
		r.maxdepth = 0;
		break;
	default:
		usage();
	} ARGEND

	if (!argc) {
		if (!(r.flags & IGNORE))
			usage();
		else
			return 0;
	}

	for (; *argv; argc--, argv++)
		recurse(AT_FDCWD, *argv, NULL, &r);

	return rm_status || recurse_status;
}
