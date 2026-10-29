# The mutations of the end-to-end run that stage finalize relies on, sourced
# by scripts/mutate.sh: the exit status of the application and the
# permission bits read through mode_of.
mutations+=(
	'scripts/e2e.sh|s/^kill -TERM "$app"$/kill -KILL "$app"/|an application that does not end with 0 passes'
	'scripts/env.sh|s/stat -c %a "$1"/stat -c %u "$1"/|the mode of a file is read as its owner'
)
