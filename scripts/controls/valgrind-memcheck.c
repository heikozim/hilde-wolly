/* The control of the valgrind variant (scripts/finalize-linux.sh): a branch
   on memory that was never written, which memcheck must report; with
   --error-exitcode the programme then ends with that status and not 0. */
#include <stdlib.h>

int main(void)
{
	int *p = malloc(sizeof *p);
	int r = 0;

	if (p == NULL)
		return 2;
	if (*p == 42)
		r = 0;
	free(p);
	return r;
}
