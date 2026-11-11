/* The control of the runs under OpenBSD's malloc options
   (the BSD part of stage finalize): a write one byte past the end of a small
   allocation.  With MALLOC_OPTIONS=S malloc puts a canary behind every
   chunk and checks it in free(3), which must end the programme; without the
   option the write goes unnoticed and the programme ends with 0, so a run
   under S that passes has its checks on.  Built without instrument flags. */
#include <stdlib.h>

int main(void)
{
	volatile unsigned char *p = malloc(30);

	if (p == NULL)
		return 2;
	p[30] = 0x55;
	free((void *)p);
	return 0;
}
