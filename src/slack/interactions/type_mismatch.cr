require "../type_mismatch"

# The name that interaction accessors used before `Slack::TypeMismatch` moved
# out of `Slack::Interactions`. Rescues of either name catch the same error.
alias Slack::Interactions::TypeMismatch = Slack::TypeMismatch
