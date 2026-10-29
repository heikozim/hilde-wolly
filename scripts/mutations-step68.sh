# The mutation of step 67 that the tests did not see until the passkey that does not count was tested.
mutations+=(
	"Passkey.hiq|s/(sign_count = 0 AND ? = 0)/(sign_count = 0 AND ? = 1)/|a passkey that does not count is refused"
	"Passkey.hiq|s/(sign_count = 0 AND CAST(? AS BIGINT) = 0)/(sign_count = 0 AND CAST(? AS BIGINT) = 1)/|pg: a passkey that does not count is refused"
)
