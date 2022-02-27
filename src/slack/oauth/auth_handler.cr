# https://api.slack.com/authentication/oauth-v2
class Slack::AuthHandler
  delegate client_id, client_secret, to: Slack.settings

  property http_client

  def initialize(@http_client : HTTP::Client.class = HTTP::Client)
  end

  Habitat.create do
    setting oauth_redirect_url : String = ENV["OAUTH_REDIRECT_URL"]
  end

  def self.run(request : HTTP::Request, http_client = HTTP::Client)
    new(http_client).authenticate_user(request)
  end

  def redirect_url
    "https://slack.com/oauth/v2/authorize?scope=#{scope}&client_id=#{client_id}"
  end

  def authenticate_user(request : HTTP::Request)
    code = request.query_params["code"]
    headers = HTTP::Headers.new
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    response = http_client.post(
      url: "https://slack.com/api/oauth.v2.access",
      headers: headers,
      form: URI::Params.encode({
        code:          code,
        client_id:     client_id,
        client_secret: client_secret,
        redirect_uri:  settings.oauth_redirect_url,
      })
    )

    Slack::AuthResponse.from_json(response.body)
  end

  private def scope
    Slack.settings.app_scopes.join(",")
  end
end
