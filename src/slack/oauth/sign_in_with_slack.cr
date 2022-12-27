# https://api.slack.com/authentication/sign-in-with-slack
class Slack::SignInWithSlack
  Habitat.create do
    setting sign_in_redirect_url : String = ENV["SIGN_IN_REDIRECT_URL"]
    setting scopes : Array(String) = [
      "openid",
      "email",
      "profile",
    ]
  end

  delegate bot_scopes, client_id, client_secret, user_scopes, to: Slack.settings

  property http_client

  def initialize(client : HTTP::Client)
    @http_client = client
  end

  def initialize(client : Nil)
    @http_client = default_client
  end

  def initialize
    @http_client = default_client
  end

  private def default_client
    HTTP::Client.new("slack.com", port: 443, tls: true)
  end

  def self.run(request : HTTP::Request, http_client = nil)
    new(http_client).authenticate_user(request)
  end

  def redirect_url
    params = HTTP::Params.encode({
      client_id:     client_id,
      scope:         settings.scopes.join(" "),
      redirect_uri:  settings.sign_in_redirect_url,
      response_type: "code",
    })

    URI.decode_www_form(
      URI.new("https", "slack.com/openid/connect/authorize", query: params).to_s
    )
  end

  def authenticate_user(request : HTTP::Request)
    code = request.query_params["code"]
    headers = HTTP::Headers.new
    headers["Content-Type"] = ContentTypes::FormEncoded.to_s
    headers["Accept"] = ContentTypes::JSON.to_s

    # TODO: add state and nonce to the request to prevent CSRF and replay attacks
    # TODO: add a team scope to the request to limit the user to a specific team,
    # and to allow the user to easily login to multiple teams
    response = http_client.post(
      "/api/openid.connect.token",
      headers: headers,
      form: URI::Params.encode({
        code:          code,
        client_id:     client_id,
        client_secret: client_secret,
        grant_type:    "authorization_code",
        redirect_uri:  settings.sign_in_redirect_url,
      })
    )

    Slack::SignInResponse.from_json(response.body).decoded_response
  end
end
