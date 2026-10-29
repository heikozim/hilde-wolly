# The mutations of stage finalize on Linux, sourced by scripts/mutate.sh
# finalize: each breaks one check of scripts/build.sh, scripts/e2e.sh or
# scripts/finalize-linux.sh, and QUICK=1 scripts/finalize-linux.sh must fail.
mutations+=(
	'scripts/build.sh|s/memory) flags=(-fsanitize=address,undefined /memory) flags=(/|the memory variant builds without ASan and UBSan'
	'scripts/build.sh|s/race) flags=(-fsanitize=thread /race) flags=(/|the race variant builds without TSan'
	'scripts/e2e.sh|s/exec "${DETACH\[@\]}" "${APP_WRAP\[@\]}" /exec "${DETACH[@]}" /|the application runs without its wrapper'
	'examples/hello/Hello.hiq|s/confineServer\("hello"\);/skip;/|hello starts without its sandbox'
	'scripts/finalize-linux.sh|s/--error-exitcode=66 //|valgrind reports a fault and the programme still ends with 0'
)
