# The mutations of the Hiawatha configuration for static files,
# sourced by scripts/mutate.sh.  All four break scripts/e2e.sh and are
# caught by the end-to-end run of examples/hello or not at all.
mutations+=(
	"scripts/e2e.sh|s#\"    Match ^/static/ Exit\" ##|static files go to the application"
	"scripts/e2e.sh|s#\"UseDirectory = static\"#\"UseDirectory = static\" \"AllowDotFiles = yes\"#|dot files are served"
	"scripts/e2e.sh|s#\"    ExpirePeriod = 1 day, public\"#\"    ExpirePeriod = 1 day, public\" \"    ShowIndex = yes\"#|a directory under /static/ is listed"
	"scripts/e2e.sh|s#\"    ExpirePeriod = 1 day, public\"#\"    ExpirePeriod = 1 day, public\" \"    FollowSymlinks = yes\"#|a symlink out of WebsiteRoot is followed"
)
