# The mutations of the request id in the access log, sourced by
# scripts/mutate.sh.
mutations+=(
	'Middleware.hiq|s/addText(counted, "request_id", asSpan(&id))/counted/|the access log has no request id'
	'Middleware.hiq|s/"X-Request-Id", asSpan(&id)/"X-Request-Ix", asSpan(\&id)/|the answer does not carry its request id'
	'Middleware.hiq|s/randomBytes(requestIdBytes)/randomBytes(0)/|every request gets the same empty id'
)
