/*
 * Example postgres ISBN-10/ISBN-13/EAN-13 validation function.
 * Written by Eddy L O Jansson, 2008-12 <eddy at klopper.net>
 * Donated into the Public Domain
 *
 * Input is varchar, clean of whitespace and dashes, output is true or false.
 *
 * NOTE 1:
 *   Are you sure you shouldn't be using the 'isn' module instead?
 *
 * NOTE 2:
 *   If NOT compiled with CHECK_VALID_DIGITS, the code will NOT check that the
 *   input contains only digits (and 'X'). This can cause false positives, but
 *   the check is a redundant time-waster if the input is guaranteed to be
 *   well formed to begin with.
 */
#ifdef CHECK_VALID_DIGITS
#include <ctype.h>
#endif
#ifdef TEST
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#else
#include <postgres.h>
#include <fmgr.h>
#endif

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

/* extern Datum is_valid_isbn(PG_FUNCTION_ARGS); */

static int is_valid_isbn10(const char* isbn) {
	int sum = 0;
	int i;
#ifdef TEST
	if (!isbn || strlen(isbn) != 10) return 0;
#endif
	for (i = 0 ; i < 9 ; ++i) {
#ifdef CHECK_VALID_DIGITS
		if (!isdigit(isbn[i]) || (isbn[i] == 'X') || (isbn[i] == 'x')) return 0;
#endif		
		sum += (10-i) * (isbn[i]-48);
	}
	if ((isbn[i] == 'X') || (isbn[i] == 'x')) {
		sum += 10;
	} else {
#ifdef CHECK_VALID_DIGITS
		if (!isdigit(isbn[i])) return 0;
#endif		
		sum += isbn[i]-48;
	}
	return (sum % 11) == 0 ? 1 : 0; 
}

static int is_valid_isbn13(const char* isbn) {
	int sum = 0;
	int i;
#ifdef TEST
	if (!isbn || strlen(isbn) != 13) return 0;
#endif
	for (i = 0 ; i < 12 ; ++i) {
#ifdef CHECK_VALID_DIGITS
		if (!isdigit(isbn[i])) return 0;
#endif		
		sum += (i & 1 ? 3 : 1) * (isbn[i]-48);
	}
	/* CHECK_VALID_DIGITS not needed here */
	return (10 - (sum % 10) == isbn[i]-48) ? 1 : 0;
}


#ifndef TEST
PG_FUNCTION_INFO_V1(is_valid_isbn);

Datum is_valid_isbn(PG_FUNCTION_ARGS) {

	if (PG_ARGISNULL(0))
		PG_RETURN_BOOL(0);
		
	VarChar* isbn = PG_GETARG_VARCHAR_P(0);
	
	int isbn_len = VARSIZE(isbn) - VARHDRSZ;
	const char* cisbn = (const char*)VARDATA(isbn);

	if (isbn_len == 10)
		PG_RETURN_BOOL(is_valid_isbn10(cisbn));
	else if (isbn_len == 13)
		PG_RETURN_BOOL(is_valid_isbn13(cisbn));

	PG_RETURN_BOOL(0);
}
#else
int main(int argc __attribute__((unused)), char* argv[] __attribute__((unused)))
{
	char* isbn[] = { "020189685;", "1234", "9780201896855", "eddyrularfet5", "0201896850", "097207631X", NULL };
	int isbn_res10[] = {  0,         0,          0,               0,               1,           1,         0  };
	int isbn_res13[] = {  0,         0,          1,               0,               0,           0,         0  };
	int isbns = sizeof(isbn) / sizeof isbn[0];
	int i;

	for(i=0 ; i < isbns ; ++i)
	{
		int is10 = is_valid_isbn10(isbn[i]);
		int is13 = is_valid_isbn13(isbn[i]);
		printf("is_valid_isbn10(%s): %d\nis_valid_isbn13(%s): %d\n", isbn[i], is10, isbn[i], is13);
		if (is10 != isbn_res10[i]) 
			printf("** WRONG RESULT FOR is_valid_isbn10(%s) **\n", isbn[i]);
		if (is13 != isbn_res13[i]) 
			printf("** WRONG RESULT FOR is_valid_isbn13(%s) **\n", isbn[i]);
		
		
	}
	return EXIT_SUCCESS;
}
#endif

