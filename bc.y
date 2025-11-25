%{
#include <libgen.h>
#include <unistd.h>

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "arg.h"
#include "util.h"

#define DIGITS   "0123456789ABCDEF"
#define NESTED_MAX 10

#define funid(f) ((f)[0] - 'a' + 1)

int yydebug;

typedef struct macro Macro;

struct macro {
	int op;
	int id;
	int flowid;
	int nested;
};

static int yyerror(char *);
static int yylex(void);

static void quit(void);
static char *code(char *, ...);
static char *forcode(Macro *, char *, char *, char *, char *);
static char *whilecode(Macro *, char *, char *);
static char *ifcode(Macro *, char *, char *);
static char *funcode(Macro *, char *, char *, char *);
static Macro *define(char *, char *);
static char *retcode(char *);
static char *brkcode(void);
static Macro *macro(int, int);

static char *ftn(char *);
static char *var(char *);
static char *ary(char *);
static void writeout(char *);

static size_t used;
static char *yytext, *buff;
static char *filename;
static FILE *filep;
static int lineno, nerr;
static jmp_buf recover;
static int nested;
static Macro macros[NESTED_MAX];
int cflag, dflag, lflag, sflag;

%}

%union {
	char *str;
	char id[2];
	Macro *macro;
}

%token <id> ID
%token <str> STRING NUMBER
%token <str> EQOP '+' '-' '*' '/' '%' '^' INCDEC
%token HOME LOOP
%token DOT
%token EQ
%token LE
%token GE
%token NE
%token DEF
%token BREAK
%token QUIT
%token LENGTH
%token RETURN
%token FOR
%token IF
%token WHILE
%token SQRT
%token SCALE
%token IBASE
%token OBASE
%token AUTO
%token PRINT

%type <str> assign nexpr expr exprstat rel stat ary statlst cond
%type <str> autolst arglst parlst
%type <str> params param locals local
%type <macro> def if for while

%right	'=' EQOP
%left	'+' '-'
%left	'*' '/' '%'
%right	'^'

%start    program

%%

program  :
         | item program        {used = 0;}
         ;

item     : scolonlst '\n'
         | def parlst '{' '\n' autolst statlst '}' {funcode($1, $2, $5, $6);}
         ;

scolonlst:
         | stat                 {writeout($1);}
         | scolonlst ';' stat   {writeout($3);}
         | scolonlst ';'
         ;

statlst :                       {$$ = code("");}
        | stat
        | statlst '\n' stat     {$$ = code("%s%s", $1, $3);}
        | statlst ';' stat      {$$ = code("%s%s", $1, $3);}
        | statlst '\n'
        | statlst ';'
        ;

stat    : exprstat
        | PRINT expr            {$$ = code("%sps.", $2);}
        | STRING                {$$ = code("[%s]P", $1);}
        | BREAK                 {$$ = brkcode();}
        | QUIT                  {quit();}
        | RETURN                {$$ = retcode("0");}
        | RETURN '(' expr ')'   {$$ = retcode($3);}
        | RETURN '(' ')'        {$$ = retcode("0");}
        | while cond stat       {$$ = whilecode($1, $2, $3);}
        | if cond stat          {$$ = ifcode($1, $2, $3);}
        | '{' statlst '}'       {$$ = $2;}
        | for '(' expr ';' rel ';' expr ')' stat  {$$ = forcode($1, $3, $5, $7, $9);}
        ;

while   : WHILE                 {$$ = macro(LOOP, 0);}
        ;

if      : IF                    {$$ = macro(IF, 0);}
        ;

for     : FOR                   {$$ = macro(LOOP, 0);}
        ;

def     : DEF ID                {$$ = macro(DEF, funid($2));}
        ;

parlst  : '(' ')'               {$$ = "%s";}
        | '(' params ')'        {$$ = $2;}
        ;

params  : param
        | params ',' param      {$$ = code("%s%s", $1, $3);}
        ;

param   : ID                    {$$ = code("S%s%%sL%ss.", var($1), var($1));}
        | ID '[' ']'            {$$ = code("S%s%%sL%ss.", ary($1), ary($1));}
        ;

autolst :                       {$$ = "%s";}
        | AUTO locals '\n'      {$$ = $2;}
        | AUTO locals ';'       {$$ = $2;}
        ;

locals  : local
        | locals ',' local      {$$ = code("%s%s", $1, $3);}
        ;

local   : ID                    {$$ = code("0S%s%%sL%ss.", var($1), var($1));}
        | ID '[' ']'            {$$ = code("0S%s%%sL%ss.", ary($1), ary($1));}
        ;

arglst  : expr
        | ID '[' ']'            {$$ = code("%s", ary($1));}
        | expr ',' arglst       {$$ = code("%s%s", $1, $3);}
        | ID '[' ']' ',' arglst {$$ = code("%s%s", ary($1), $5);}
        ;

cond    : '(' rel ')'           {$$ = $2;}
        ;

rel     : expr                  {$$ = code("%s 0!=", $1);}
        | expr EQ expr          {$$ = code("%s%s=", $3, $1);}
        | expr LE expr          {$$ = code("%s%s!>", $3, $1);}
        | expr GE expr          {$$ = code("%s%s!<", $3, $1);}
        | expr NE expr          {$$ = code("%s%s!=", $3, $1);}
        | expr '<' expr         {$$ = code("%s%s<", $3, $1);}
        | expr '>' expr         {$$ = code("%s%s>", $3, $1);}
        ;

exprstat: nexpr                 {$$ = code("%s%ss.", $1, sflag ? "" : "p");}
        | assign                {$$ = code("%ss.", $1);}
        ;

expr    : nexpr
        | assign
        ;

nexpr   : NUMBER                {$$ = code(" %s", $1);}
        | ID                    {$$ = code("l%s", var($1));}
        | DOT                   {$$ = code("l.");}
        | SCALE                 {$$ = code("K");}
        | IBASE                 {$$ = code("I");}
        | OBASE                 {$$ = code("O");}
        | ID ary                {$$ = code("%s;%s", $2, ary($1));}
        | '(' expr ')'          {$$ = $2;}
        | ID '(' arglst ')'     {$$ = code("%sl%sx", $3, ftn($1));}
        | ID '(' ')'            {$$ = code("l%sx", ftn($1));}
        | '-' expr              {$$ = code("0%s-", $2);}
        | expr '+' expr         {$$ = code("%s%s+", $1, $3);}
        | expr '-' expr         {$$ = code("%s%s-", $1, $3);}
        | expr '*' expr         {$$ = code("%s%s*", $1, $3);}
        | expr '/' expr         {$$ = code("%s%s/", $1, $3);}
        | expr '%' expr         {$$ = code("%s%s%", $1, $3);}
        | expr '^' expr         {$$ = code("%s%s^", $1, $3);}
        | LENGTH '(' expr ')'   {$$ = code("%sZ", $3);}
        | SQRT '(' expr ')'     {$$ = code("%sv", $3);}
        | SCALE '(' expr ')'    {$$ = code("%sX", $3);}
        | INCDEC ID             {$$ = code("l%s1%sds%s", var($2), $1, var($2));}
        | INCDEC SCALE          {$$ = code("K1%sk", $1);}
        | INCDEC IBASE          {$$ = code("I1%sdi", $1);}
        | INCDEC OBASE          {$$ = code("O1%sdo", $1);}
        | INCDEC ID ary         {$$ = code("%sdS_;%s1%sdL_:%s", $3, ary($2), $1, ary($2));}
        | ID INCDEC             {$$ = code("l%sd1%ss%s", var($1), $2, var($1));}
        | SCALE INCDEC          {$$ = code("Kd1%sk", $2);}
        | IBASE INCDEC          {$$ = code("Id1%si", $2);}
        | OBASE INCDEC          {$$ = code("Od1%so", $2);}
        | ID ary INCDEC         {$$ = code("%sds.;%sd1%sl.:%s", $2, ary($1), $3, ary($1));}
        ;

assign  : ID '=' expr           {$$ = code("%sds%s", $3, var($1));}
        | SCALE '=' expr        {$$ = code("%sdk", $3);}
        | IBASE '=' expr        {$$ = code("%sdi", $3);}
        | OBASE '=' expr        {$$ = code("%sdo", $3);}
        | ID ary '=' expr       {$$ = code("%sd%s:%s", $4, $2, ary($1));}
        | ID EQOP expr          {$$ = code("%sl%s%sds%s", $3, var($1), $2, var($1));}
        | SCALE EQOP expr       {$$ = code("%sK%sdk", $3, $2);}
        | IBASE EQOP expr       {$$ = code("%sI%sdi", $3, $2);}
        | OBASE EQOP expr       {$$ = code("%sO%sdo", $3, $2);}
        | ID ary EQOP expr      {$$ = code("%s%sds.;%s%sdl.:s", $4, $2, ary($1), $3, ary($1));}
        ;

ary     : '[' expr ']'          {$$ = $2;}
        ;

%%
static int
yyerror(char *s)
{
	fprintf(stderr, "bc: %s:%d: %s\n", filename, lineno, s);
	nerr++;
	longjmp(recover, 1);
}

static void
writeout(char *s)
{
	if (write(1, s, strlen(s)) < 0)
		goto err;
	if (write(1, (char[]){'\n'}, 1) < 0)
		goto err;
	return;
	
err:
	eprintf("writing to dc:");
}

static char *
code(char *fmt, ...)
{
	char *s;
	va_list va;
	size_t n, room;

	va_start(va, fmt);
	room = BUFSIZ - used;
	n = vsnprintf(buff+used, room, fmt, va);
	va_end(va);

	if (n < 0 || n >= room)
		eprintf("unable to code requested operation\n");

	s = buff + used;
	used += n + 1;

	return s;
}

static Macro *
macro(int op, int id)
{
	Macro *d;

	if (nested == NESTED_MAX)
		yyerror("too much nesting");

	d = &macros[nested];
	d->flowid = (op == HOME) ? '0' - 1: d[-1].flowid + 1;
	d->id = (id != 0) ? id : d->flowid;
	d->op = op;
	d->nested = nested++;

	return d;
}

static char *
funcode(Macro *d, char *params, char *vars, char *body)
{
	char *s;

	s = code(vars, params);
	s = code(s, body);
	s = code("[%s 0 1Q]s%c", s, d->id);
	nested--;
	writeout(s);

	return s;
}

static char *
brkcode(void)
{
	Macro *d;

	for (d = &macros[nested-1]; d->op != HOME && d->op != LOOP; --d)
		;
	if (d->op == HOME)
		yyerror("break not in for or while");
	return code(" %dQ", nested  - d->nested);
}

static char *
forcode(Macro *d, char *init, char *cmp, char *inc, char *body)
{
	char *s;

	s = code("[%s%ss.%s%c]s%c",
	         body,
	         inc,
	         cmp,
	         d->flowid, d->flowid);
	writeout(s);

	s = code("%ss.%s%c", init, cmp, d->flowid);
	nested--;

	return s;
}

static char *
whilecode(Macro *d, char *cmp, char *body)
{
	char *s;

	s = code("[%ss.%s%c]s%c", body, cmp, d->flowid, d->flowid);
	writeout(s);

	s = code("%s%c", cmp, d->flowid);
	nested--;

	return s;
}

static char *
ifcode(Macro *d, char *cmp, char *body)
{
	char *s;

	s = code("[%s]s%c", body, d->flowid);
	writeout(s);

	s = code("%s%c", cmp, d->flowid);
	nested--;

	return s;
}

static char *
retcode(char *expr)
{
	char *s;

	if (nested < 2 || macros[1].op != DEF)
		yyerror("return must be in a function");
	return code("%s %dQ", expr, nested - 1);
}

static char *
ary(char *s)
{
	return code("%c", toupper(s[0]));
}

static char *
ftn(char *s)
{
	return code("%c", funid(s));
}

static char *
var(char *s)
{
	return code("%s", s);
}

static void
quit(void)
{
	exit(nerr > 0 ? 1 : 0);
}

static void
skipspaces(void)
{
	int ch;

	while (isspace(ch = getc(filep))) {
		if (ch == '\n') {
			lineno++;
			break;
		}
	}
	ungetc(ch, filep);
}

static int
iden(int ch)
{
	static struct keyword {
		char *str;
		int token;
	} keywords[] = {
		{"define", DEF},
		{"break", BREAK},
		{"quit", QUIT},
		{"length", LENGTH},
		{"return", RETURN},
		{"for", FOR},
		{"if", IF},
		{"while", WHILE},
		{"sqrt", SQRT},
		{"scale", SCALE},
		{"ibase", IBASE},
		{"obase", OBASE},
		{"auto", AUTO},
		{"print", PRINT},
		{NULL}
	};
	struct keyword *p;
	char *bp;

	ungetc(ch, filep);
	for (bp = yytext; bp < &yytext[BUFSIZ]; ++bp) {
		ch = getc(filep);
		if (!islower(ch))
			break;
		*bp = ch;
	}

	if (bp == &yytext[BUFSIZ])
		yyerror("too long token");
	*bp = '\0';
	ungetc(ch, filep);

	if (strlen(yytext) == 1) {
		strcpy(yylval.id, yytext);
		return ID;
	}

	for (p = keywords; p->str && strcmp(p->str, yytext); ++p)
		;

	if (!p->str)
		yyerror("invalid keyword");

	return p->token;
}

static char *
digits(char *bp)
{
	int ch;
	char *digits = DIGITS, *p;

	while (bp < &yytext[BUFSIZ]) {
		ch = getc(filep);
		p = strchr(digits, ch);
		if (!p)
			break;
		*bp++ = ch;
	}

	if (bp == &yytext[BUFSIZ])
		return NULL;
	ungetc(ch, filep);

	return bp;
}

static int
number(int ch)
{
	int d;
	char *bp;

	ungetc(ch, filep);
	if ((bp = digits(yytext)) == NULL)
		goto toolong;

	if ((ch = getc(filep)) != '.') {
		ungetc(ch, filep);
		goto end;
	}
	*bp++ = '.';

	if ((bp = digits(bp)) == NULL)
		goto toolong;

end:
	if (bp ==  &yytext[BUFSIZ])
		goto toolong;
	*bp = '\0';
	yylval.str = yytext;

	return NUMBER;

toolong:
	yyerror("too long number");
}

static int
string(int ch)
{
	char *bp;

	for (bp = yytext; bp < &yytext[BUFSIZ]; ++bp) {
		if ((ch = getc(filep)) == '"')
			break;
		*bp = ch;
	}

	if (bp == &yytext[BUFSIZ])
		yyerror("too long string");
	*bp = '\0';
	yylval.str = yytext;

	return STRING;
}

static int
follow(int next, int yes, int no)
{
	int ch;

	ch = getc(filep);
	if (ch == next)
		return yes;
	ungetc(ch, filep);
	return no;
}

static int
operand(int ch)
{
	int peekc;

	switch (ch) {
	case '\n':
	case '{':
	case '}':
	case '[':
	case ']':
	case '(':
	case ')':
	case ',':
	case ';':
		return ch;
	case '.':
		peekc = ungetc(getc(filep), filep);
		if (strchr(DIGITS, peekc))
			return number(ch);
		yylval.str = ".";
		return DOT;
	case '"':
		return string(ch);
	case '*':
		yylval.str = "*";
		return follow('=', EQOP, '*');
	case '/':
		yylval.str = "/";
		return follow('=', EQOP, '/');
	case '%':
		yylval.str = "%";
		return follow('=', EQOP, '%');
	case '=':
		return follow('=', EQ, '=');
	case '+':
	case '-':
		yylval.str = (ch == '+') ? "+" : "-";
		if (follow('=', EQOP, ch) != ch)
			return EQOP;
		return follow(ch, INCDEC, ch);
	case '^':
		yylval.str = "^";
		return follow('=', EQOP, '^');
	case '<':
		return follow('=', LE, '<');
	case '>':
		return follow('=', GE, '>');
	case '!':
		if (getc(filep) == '=')
			return NE;
	default:
		yyerror("invalid operand");
	}
}

static void
comment(void)
{
	int c;

	for (;;) {
		while ((c = getc(filep)) != '*') {
			if (c == '\n')
				lineno++;
		}
		if ((c = getc(filep)) == '/')
			break;
		ungetc(c, filep);
	}
}

static int
yylex(void)
{
	int peekc, ch;

repeat:
	skipspaces();

	ch = getc(filep);
	if (ch == EOF) {
		return EOF;
	} else if (!isascii(ch)) {
		yyerror("invalid input character");
	} else if (islower(ch)) {
		return iden(ch);
	} else if (strchr(DIGITS, ch)) {
		return number(ch);
	} else {
		if (ch == '/') {
			peekc = getc(filep);
			if (peekc == '*') {
				comment();
				goto repeat;
			}
			ungetc(peekc, filep);
		}
		return operand(ch);
	}
}

static void
spawn(void)
{
	int fds[2];
	char errmsg[] = "bc:error execing dc\n";

	if (pipe(fds) < 0)
		eprintf("creating pipe:");

	switch (fork()) {
	case -1:
		eprintf("forking dc:");
	case 0:
		close(1);
		dup(fds[1]);
		close(fds[0]);
		close(fds[1]);
		break;
	default:
		close(0);
		dup(fds[0]);
		close(fds[0]);
		close(fds[1]);
		execlp("dc", "dc", (char *) NULL);

		/* it shouldn't happen */
		write(3, errmsg, sizeof(errmsg)-1);
		_Exit(2);
	}
}

static void
run(void)
{
	if (setjmp(recover)) {
		if (ferror(filep))
			eprintf("%s:", filename);
		if (feof(filep))
			return;
	}
	yyparse();
}

static void
bc(char *fname)
{
	Macro *d;

	lineno = 1;
	used = nested = 0;

	macro(HOME, 0);
	if (!fname) {
		filename = "<stdin>";
		filep = stdin;
	} else {
		filename = fname;
		if ((filep = fopen(fname, "r")) == NULL)
			eprintf("%s:", fname);
	}

	run();
	fclose(filep);
}

static void
loadlib(void)
{
	int r;
	size_t len;
	char bin[FILENAME_MAX], fname[FILENAME_MAX];
	static char bclib[] = "bc.library";

	/*
	 * try first to load the library from the same directory than
	 * the executable, because that can makes easier the tests
	 * because it does not require to install to test the last version
	 */
	len = strlen(argv0);
	if (len >= FILENAME_MAX)
		goto share;
	memcpy(bin, argv0, len + 1);

	r = snprintf(fname, sizeof(fname), "%s/%s", dirname(bin), bclib);
	if (r < 0 || r >= sizeof(fname))
		goto share;

	if (access(fname, F_OK) < 0)
		goto share;

	bc(fname);
	return;

share:
	r = snprintf(fname, sizeof(fname), "%s/share/misc/%s", PREFIX, bclib);
	if (r < 0 || r >= sizeof(fname))
		eprintf("invalid path name for bc.library\n");
	bc(fname);
}

static void
usage(void)
{
	eprintf("usage: %s [-cdls]\n", argv0);
}

int
main(int argc, char *argv[])
{
	ARGBEGIN {
	case 'c':
		cflag = 1;
		break;
	case 'd':
		dflag = 1;
		yydebug = 3;
		break;
	case 'l':
		lflag = 1;
		break;
	case 's':
		sflag = 1;
		break;
	default:
		usage();
	} ARGEND

	yytext = malloc(BUFSIZ);
	buff = malloc(BUFSIZ);
	if (!yytext || !buff)
		eprintf("out of memory\n");

	if (!cflag)
		spawn();
	if (lflag)
		loadlib();

	if (*argv == NULL) {
		bc(NULL);
	} else {
		while (*argv)
			bc(*argv++);
	}

	quit();
}
