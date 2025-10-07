#include <stddef.h>
#include <time.h>

typedef struct target Target;

enum {
	NOEXPORT,
	EXPORT,
};

enum {
	UNDEF,
	ENVIRON,
	CMDLINE,
	INTERNAL,
	MAKEFILE,
	MAKEFLAGS,
};

struct loc {
	char *fname;
	int lineno;
};

struct action {
	char *line;
	struct loc loc;
};

struct target {
	char *name;
	char *target;
	char *req;
	time_t stamp;
	int defined;

	int ndeps;
	struct target **deps;

	int nactions;
	struct action *actions;

	struct target *next;
};

extern void *emalloc(size_t);
extern void *erealloc(void *, size_t);
extern char *estrdup(char *);

extern void dumprules(void);
extern void dumpmacros(void);

extern char *expandstring(char *, Target *, struct loc *);
extern void addtarget(char *, int);
extern void inject(char *);
extern int build(char *);
extern int hash(char *);
extern int parse(char *);
extern void debug(char *, ...);
extern void error(char *, ...);
extern void warning(char *, ...);
extern void adddep(char *, char *);
extern void addrule(char *, struct action *, int);
extern void freeloc(struct loc *);

extern char *getmacro(char *);
extern void setmacro(char *, char *, int, int);

/* system depdendant */
extern time_t stamp(char *);
extern int launch(char *, int);
extern int putenv(char *);
extern void exportvar(char *, char *);
extern int is_dir(char *);

/* main.c */
extern int kflag, dflag, nflag, iflag, sflag;
extern int eflag, pflag, tflag, qflag;
extern int exitstatus;

#ifdef SIGABRT
extern volatile sig_atomic_t stop;
#endif

/* defaults.c */
extern char defaults[];
