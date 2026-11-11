# The cases of scripts/e2e.sh against examples/pages, sourced there: the
# routes of its tree of route modules and the one route set by hand.
app_cases() {
	echo "== segments"
	expect "the root from index.hih" 200 "/" "<h1>Home</h1>"
	expect "about.hih is /about" 200 "/about" "<h1>About</h1>"
	expect "routes/docs/intro.hih is /docs/intro" 200 "/docs/intro" "<h1>Intro</h1>"
	expect "a directory without a page" 404 "/docs" "not found"
	expect "405 with the methods of the page" 405 "/about" "^Allow: GET$" -X POST -d ''

	echo "== layouts"
	expect "_admin wraps its page" 200 "/users" '<main class="admin">'
	expect "and adds no segment" 404 "/admin/users" "not found"
	expect "the panel inside the admin layout" 200 "/audit" '<section class="panel">'
	check "the inner layout first" bash -c "tr -d '\\n' < '$last.body' | grep -q '<main class=\"admin\"><section class=\"panel\"><h1>Audit</h1></section></main>'"
	expect "a finished answer is not wrapped" 303 "/settings" "^Location: /settings$" --data-raw "x=1"
	check "no layout around it" bash -c "! grep -q '<main' '$last.body'"

	echo "== parameters"
	expect "a typed parameter" 200 "/post/42" "<h1>Post 42</h1>"
	expect "a static segment before the parameter" 200 "/post/new" "<h1>New post</h1>"
	expect "a value parse refuses" 404 "/post/0" "not found"
	expect "no letter" 404 "/post/4x" "not found"
	expect "two parameters in the order of the path" 200 "/post/42/comments/7" "<p>Comment 7 of post 42</p>"
	expect "the second has its own type" 404 "/post/42/comments/1000" "not found"

	echo "== the route set by hand"
	expect "GET /health" 200 "/health" "^ok$"
}
