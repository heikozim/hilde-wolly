/* The control of the trap variant (the BSD part of stage finalize): a signed
   overflow, which UBSan in trap mode must stop with a trap; it prints
   nothing, the signal is the report. */
#include <limits.h>

int main(void)
{
	volatile int x = INT_MAX;

	x = x + 1;
	return x == INT_MIN ? 0 : 1;
}
