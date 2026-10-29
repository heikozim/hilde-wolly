# The mutations of the check that every public function states its
# contract (the job contracts-stated of scripts/test.sh),
# sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"scripts/check-contracts.pl|s/push @miss, \[\$at, \$name\] unless/push @miss, [\$at, \$name] if 0 and/|a declaration without a contract passes the check"
	"scripts/check-contracts.pl|s/|| \$doc =~ \/^\\\\s\*No contract:\/m;/|| \$doc =~ \/No contract:\/m;/|a No contract: in the middle of a line passes"
	"src/Wolly/Limit.hih|/No contract: the answer is the work of the database\./d|a function without a contract or its reason passes the gate"
)
