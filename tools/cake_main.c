#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>

/* Replaces this process with the runtime that shipped inside the app. */
int main(int argc, char **argv) {
	char exe[4096];
	uint32_t size = sizeof(exe);
	if (_NSGetExecutablePath(exe, &size) != 0) {
		fprintf(stderr, "This copy of the cake is missing its runtime.\n");
		return 1;
	}
	char *slash = strrchr(exe, '/');
	if (slash) *slash = '\0';
	char runtime[4096];
	char pack[4096];
	snprintf(runtime, sizeof(runtime), "%s/cake-runtime", exe);
	snprintf(pack, sizeof(pack), "%s/../Resources/cake.pck", exe);
	if (access(runtime, X_OK) != 0 || access(pack, R_OK) != 0) {
		fprintf(stderr, "This copy of the cake is missing its runtime.\n");
		return 1;
	}
	char **args = calloc((size_t)argc + 3, sizeof(char *));
	if (!args) return 1;
	args[0] = runtime;
	args[1] = "--main-pack";
	args[2] = pack;
	for (int i = 1; i < argc; i++) args[i + 2] = argv[i];
	execv(runtime, args);
	perror("cake runtime");
	return 1;
}
