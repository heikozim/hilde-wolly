# The mutations of the jobs of a test run (scripts/jobs.sh), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh; scripts/jobs.test.sh sees them.
mutations+=(
	"scripts/jobs.sh|s/^\t\t\*) failed=\$((failed + 1)) ;;/\t\t*) ;;/|a failed job counts as green"
	"scripts/jobs.sh|s/if \[ \"\$rc\" -ne 0 \]; then/if false; then/|a job starts after the one it needs failed"
	"scripts/jobs.sh|s/\[ \"\$running\" -lt \"\$slots\" \] || break/true/|more jobs at once than slots"
	"scripts/jobs.sh|s/JOB_RC\[\${JOB_NAME\[\$k\]}\]=\$rc/JOB_RC[\${JOB_NAME[\$k]}]=0/|the exit of a job side by side is lost"
	"scripts/jobs.sh|s/^\t(eval \"\$1\")/\t(eval \"\$1\"); true/|the exit of every job is lost"
	"scripts/jobs.sh|s/^\t\techo \"== job \${JOB_NAME\[\$i\]}\"/\t\techo \"== job\"/|the merged logs do not name their jobs"
)
