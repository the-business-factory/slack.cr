# Run with: crystal run examples/user_group.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/user_group_example"

OfflineUserGroupExample.run
