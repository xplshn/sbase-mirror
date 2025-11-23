%{
#include <unistd.h>

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

int yydebug;

typedef struct macro Macro;

struct macro {
	char *init;
	char *cmp;
	char *inc;
	char *vars;
	char *body;
	int n;
};

static int yyerror(char *);
static int yylex(void);

static void quit(void);
static char *code(char *, ...);
static char *forcode(Macro, char *);
static char *whilecode(Macro, char *);
static char *ifcode(Macro, char *);
static char *funcode(Macro, char *, char *);
static Macro macro(char *, char *, char *);
static Macro function(char *, char *);

static char *ftn(char *);
static char *var(char *);
static char *ary(char *);
static void writeout(char *);

static size_t used;
static char *yytext, *buff;
static char *filename = "<stdin>";
static int lineno, nerr;
static jmp_buf recover;
static int nested;
int cflag, dflag, lflag, sflag;

%}

%union {
	char *str;
	char id[2];
	Macro macro;
}

%token <id> ID
%token <str> STRING NUMBER
%token <str> EQOP '+' '-' '*' '/' '%' '^' INCDEC
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

%type <str> assign nexpr expr exprstat rel stat ary statlst
%type <str> autolst arglst
%type <str> parlst locals local
%type <str> function
%type <macro> fordef cond funbody

%right	'=' EQOP
%left	'+' '-'
%left	'*' '/' '%'
%right	'^'

%start    program

%%

program  :
         | item program
         ;

item     : scolonlst '\n'
         | function             {writeout($1);}
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
        | STRING                {$$ = code("[%s]P", $1);}
        | BREAK                 {$$ = code(" %dQ", nested);}
        | QUIT                  {quit();}
        | RETURN
        | RETURN '(' expr ')'
        | RETURN '(' ')'
        | FOR fordef stat       {$$ = forcode($2, $3);}
        | IF cond stat          {$$ = ifcode($2, $3);}
        | WHILE cond stat       {$$ = whilecode($2, $3);}
        | '{' statlst '}'       {$$ = $2;}
        ;

fordef  : '(' expr ';' rel ';' expr ')' {$$ = macro($2, $4, $6);}
        ;

cond    : '(' rel ')'           {$$ = macro(NULL, $2, NULL);}
        ;

function: DEF ID parlst funbody {$$ = funcode($4, $2, $3);}
        ;

funbody : '{' '\n' autolst statlst '}' {$$ = function($3, $4);}
        ;

parlst  : '(' ')'               {$$ = "%s";}
        | '(' locals ')'        {$$ = $2;}
        ;

autolst :                       {$$ = "%s";}
        | AUTO locals '\n'      {$$ = $2;}
        | AUTO locals ';'       {$$ = $2;}
        ;

locals  : local
        | locals ',' local      {$$ = code($1, $3);}
        ;

local   : ID                    {$$ = code("S%s%%sL%ss.", var($1), var($1));}
        | ID '[' ']'            {$$ = code("S%s%%sL%ss.", ary($1), ary($1));}
        ;

arglst  : expr
        | ID '[' ']'            {$$ = code("%s", ary($1));}
        | expr ',' arglst       {$$ = code("%s%s", $1, $3);}
        | ID '[' ']' ',' arglst {$$ = code("%s%s", ary($1), $5);}
        ;

rel     : expr
        | expr EQ expr          {$$ = code("%s%s=", $3, $1);}
        | expr LE expr          {$$ = code("%s%s!>", $3, $1);}
        | expr GE expr          {$$ = code("%s%s!<", $3, $1);}
        | expr NE expr          {$$ = code("%s%s!=", $3, $1);}
        | expr '<' expr         {$$ = code("%s%s<", $3, $1);}
        | expr '>' expr         {$$ = code("%s%s>", $3, $1);}
        ;

exprstat: nexpr                 {$$ = code("%s%s", $1, sflag ? "s." : "p");}
        | assign                {$$ = code("%ss.", $1);}
        ;

expr    : nexpr
        | assign
        ;

nexpr   : NUMBER                {$$ = code(" %s", $1);}
        | ID                    {$$ = code("l%s", var($1));}
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
	fprintf(stderr, "bc: %s:%d:%s\n", filename, lineno, s);
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
	used = 0;

	return;
	
err:
	eprintf("bc:writing to dc:");
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
		eprintf("bc: unable to code requested operation\n");

	s = buff + used;
	used += n + 1;

	return s;
}

static char *
funcode(Macro d, char *id, char *params)
{
	char *s;

	s = code(d.vars, d.body);
	s = code(params, s);
	s = code("[%s]s%s", s, id);
	return s;
}

static char *
forcode(Macro d, char *body)
{
	char *s;

	s = code("[%s%ss.%s%d]s%d",
	         body,
	         d.inc,
	         d.cmp,
	         d.n, d.n);
	writeout(s);

	s = code("%ss.l%dx", d.init, d.n);
	nested--;

	return s;
}

static char *
whilecode(Macro d, char *body)
{
	char *s;

	s = code("[%ss.%s%d]s%d", body, d.cmp, d.n, d.n);
	writeout(s);

	s = code("l%dx", d.n);
	nested--;

	return s;
}

static char *
ifcode(Macro d, char *body)
{
	char *s;

	s = code("[%s]s%d", body, d.n);
	writeout(s);

	s = code("%s%d", d.cmp, d.n);
	nested--;

	return s;
}

static Macro
macro(char *init, char *cmp, char *inc)
{
	Macro d;

	if (nested == 10)
		yyerror("bc:too much nesting");

	d.init = init;
	d.cmp = cmp;
	d.inc = inc;
	d.n = nested++;

	return d;
}

static Macro
function(char *vars, char *body)
{
	Macro d;

	if (nested == 10)
		yyerror("bc:too much nesting");

	d.vars = vars;
	d.body = body;
	d.n = nested++;

	return d;
}

static char *
ary(char *s)
{
	return code("%c", toupper(s[0]));
}

static char *
ftn(char *s)
{
	return code("%c", s[0] | 0x80);
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

	while (isspace(ch = getchar())) {
		if (ch == '\n') {
			lineno++;
			break;
		}
	}
	ungetc(ch, stdin);
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
		{NULL}
	};
	struct keyword *p;
	char *bp;

	ungetc(ch, stdin);
	for (bp = yytext; bp < &yytext[BUFSIZ]; ++bp) {
		ch = getchar();
		if (!islower(ch))
			break;
		*bp = ch;
	}

	if (bp == &yytext[BUFSIZ])
		yyerror("too long token");
	*bp = '\0';
	ungetc(ch, stdin);

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
		ch = getchar();
		p = strchr(digits, ch);
		if (!p)
			break;
		*bp++ = ch;
	}

	if (bp == &yytext[BUFSIZ])
		return NULL;
	ungetc(ch, stdin);

	return bp;
}

static int
number(int ch)
{
	int d;
	char *bp;

	ungetc(ch, stdin);
	if ((bp = digits(yytext)) == NULL)
		goto toolong;

	if ((ch = getchar()) != '.') {
		ungetc(ch, stdin);
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
	yyerror("bc:too long number");
}

static int
string(int ch)
{
	char *bp;

	for (bp = yytext; bp < &yytext[BUFSIZ]; ++bp) {
		if ((ch = getchar()) == '"')
			break;
		*bp = ch;
	}

	if (bp == &yytext[BUFSIZ])
		yyerror("bc:too long string");
	*bp = '\0';
	yylval.str = yytext;

	return STRING;
}

static int
follow(int next, int yes, int no)
{
	int ch;

	ch = getchar();
	if (ch == next)
		return yes;
	ungetc(ch, stdin);
	return no;
}

static int
operand(int ch)
{
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
		if (getchar() == '=')
			return NE;
	default:
		yyerror("invalid operand");
	}
}

static void
comment(void)
{
	do {
		while (getchar() != '*')
			;
	} while (getchar() != '/');
}

static int
yylex(void)
{
	int peekc, ch;

repeat:
	skipspaces();

	ch = getchar();
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
			peekc = getchar();
			if (peekc == '*') {
				comment();
				goto repeat;
			}
			ungetc(peekc, stdin);
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
		eprintf("bc:creating pipe:");

	switch (fork()) {
	case -1:
		eprintf("bc:forking dc:");
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
init(void)
{
	used = 0;

	if (!yytext)
		yytext = malloc(BUFSIZ);
	if (!buff)
		buff = malloc(BUFSIZ);
	if (!yytext || !buff)
		eprintf("bc: out of memory\n");
}

static int
run(void)
{
	if (feof(stdin))
		return 0;

	if (setjmp(recover))
		return 1;

	yyparse();
	return 1;
}

static void
bc(char *fname)
{
	nested = lineno = 0;

	if (fname) {
		filename = fname;
		if (!freopen(fname, "r", stdin))
			eprintf("bc: %s:", fname);
	}

	for (init(); run(); init())
		;
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

	if (!cflag)
		spawn();

	if (*argv == NULL) {
		bc(NULL);
	} else {
		while (*argv)
			bc(*argv++);
	}

	quit();
}
