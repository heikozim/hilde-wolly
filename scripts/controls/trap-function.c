/* The second control of the trap variant (the BSD part of stage finalize): a call
   through a pointer of another function type, which UBSan's function check
   in trap mode must stop with a trap; it prints nothing, the signal is the
   report.  The pointer is volatile so that the call stays indirect. */
static int twice(long x)
{
	return (int)(2 * x);
}

int main(void)
{
	int (*volatile call)(int) = (int (*)(int))(void (*)(void))twice;

	return call(1) == 2 ? 0 : 1;
}
