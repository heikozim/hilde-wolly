/* The control of the memory variant (scripts/finalize-linux.sh): a read of
   memory after it was freed, which ASan must report and end the programme
   for.  UBSan does not see it, so the report is ASan's.  Built with the
   flags of the variant by scripts/build.sh. */
#include <stdlib.h>

int main(void)
{
	volatile char *p = malloc(8);

	if (p == NULL)
		return 2;
	p[0] = 1;
	free((void *)p);
	return p[0] == 1 ? 0 : 1;
}
