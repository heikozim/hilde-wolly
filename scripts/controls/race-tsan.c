/* The control of the race variant (scripts/finalize-linux.sh): two threads
   write one counter without a lock, which TSan must report as a data race;
   TSan then ends the programme with a status other than 0. */
#include <pthread.h>

static int counter;

static void *count(void *arg)
{
	(void)arg;
	for (int i = 0; i < 100000; i++)
		counter++;
	return NULL;
}

int main(void)
{
	pthread_t a, b;

	if (pthread_create(&a, NULL, count, NULL) != 0 || pthread_create(&b, NULL, count, NULL) != 0)
		return 2;
	pthread_join(a, NULL);
	pthread_join(b, NULL);
	return counter > 0 ? 0 : 1;
}
