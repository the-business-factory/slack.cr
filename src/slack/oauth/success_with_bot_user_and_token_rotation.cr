# {
#   "ok":            true,
#   "access_token":  "xoxe.xoxb-1-..",
#   "token_type":    "bot",
#   "scope":         "commands,incoming-webhook",
#   "bot_user_id":   "U0KRQLJ9H",
#   "app_id":        "A0KRD7HC3",
#   "expires_in":    43200,
#   "refresh_token": "xoxe-1-...",
#   "team":          {
#     "name": "Slack Softball Team",
#     "id":   "T9TK3CUKW",
#   },
#   "enterprise": {
#     "name": "slack-sports",
#     "id":   "E12345678",
#   },
#   "authed_user": {
#     "id":            "U1234",
#     "scope":         "chat:write",
#     "access_token":  "xoxe.xoxp-1234",
#     "expires_in":    43200,
#     "refresh_token": "xoxe-1-...",
#     "token_type":    "user",
#   },
# }
struct Slack::Auth::SuccessWithBotUserAndTokenRotation
end
