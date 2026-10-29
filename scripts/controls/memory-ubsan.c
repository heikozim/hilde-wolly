/* The control of the memory variant (scripts/finalize-linux.sh): a signed
   overflow, which UBSan must report and, without recovery, end the
   programme for. */
#include <limits.h>

int main(void)
{
	volatile int x = INT_MAX;

	x = x + 1;
	return x == INT_MIN ? 0 : 1;
}
