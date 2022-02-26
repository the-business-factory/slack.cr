# {
#     "authed_user": {
#         "id": "U1234",
#         "scope": "chat:write",
#         "access_token": "xoxp-1234",
#         "token_type": "user"
#     }
# }
struct Slack::Auth::User
  include JSON::Serializable

  property access_token : String,
    id : String,
    scope : String,
    token_type : String
end
