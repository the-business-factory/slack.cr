require "./response_parser"
require "./user"
require "./team"
require "./enterprise"

# Authorization-code response. Refresh responses use Slack::RefreshResponse.
struct Slack::AuthResponse
  getter access_token : String?
  getter app_id : String
  getter authed_user : Slack::Auth::User?
  getter bot_user_id : String?
  getter enterprise : Slack::Auth::Enterprise?
  getter expires_in : Int32?
  getter refresh_token : String?
  getter scope : String?
  getter team : Slack::Auth::Team?
  getter token_type : String?
  getter incoming_webhook : Slack::Auth::IncomingWebhook?
  getter? is_enterprise_install : Bool

  def self.from_json(body : String | IO) : self
    parse(body)
  end

  def self.parse(body : String | IO, http_status : Int32 = 200,
                 headers : HTTP::Headers = HTTP::Headers.new) : self
    new(Auth::ResponseParser.new(body, http_status, headers))
  end

  def self.parse(response : Auth::TransportResponse) : self
    parse(response.body, response.status, response.headers)
  end

  private def initialize(parser : Auth::ResponseParser)
    @app_id = parser.required_string("app_id")
    @is_enterprise_install = parser.boolean("is_enterprise_install")
    @team = parser.object("team").try do |object|
      Auth::Team.new(parser.required_string("id", object), parser.string("name", object))
    end
    @enterprise = parser.object("enterprise").try do |object|
      Auth::Enterprise.new(parser.required_string("id", object), parser.string("name", object))
    end
    parser.invalid! if @is_enterprise_install ? @enterprise.nil? : @team.nil?
    @access_token = parser.string("access_token")
    @bot_user_id = parser.string("bot_user_id")
    @scope = parser.string("scope")
    @token_type = parser.string("token_type")
    @refresh_token = parser.string("refresh_token")
    @expires_in = parser.expiry
    parser.validate_grant(@access_token, @scope, @token_type, @refresh_token, @expires_in, "bot")
    parser.invalid! if @access_token.nil? != @bot_user_id.nil?
    @authed_user = parse_user(parser)
    parser.invalid! unless @access_token || @authed_user.try(&.access_token)
    @incoming_webhook = parser.object("incoming_webhook").try do |object|
      configuration = parser.string("configuration_url", object).try { |url| Auth::Secret.new(url) }
      Auth::IncomingWebhook.new(Auth::Secret.new(parser.required_string("url", object)),
        parser.required_string("channel_id", object), configuration)
    end
  end

  private def parse_user(parser : Auth::ResponseParser) : Auth::User?
    parser.object("authed_user").try do |object|
      id = parser.required_string("id", object)
      access = parser.string("access_token", object)
      scope = parser.string("scope", object)
      type = parser.string("token_type", object)
      refresh = parser.string("refresh_token", object)
      expiry = parser.expiry(object)
      parser.validate_grant(access, scope, type, refresh, expiry, "user")
      Auth::User.new(id: id, access_token: access, scope: scope, token_type: type,
        refresh_token: refresh, expires_in: expiry)
    end
  end

  def ok? : Bool
    true
  end

  def installation_key : Auth::InstallationKey
    kind = @is_enterprise_install ? Auth::InstallationKind::Organization : Auth::InstallationKind::Workspace
    Auth::InstallationKey.new(@app_id, kind, @enterprise.try(&.id), @is_enterprise_install ? nil : @team.try(&.id))
  end

  # Read the clock once so grants in one exchange have the same time origin.
  def installation_patch(clock : Auth::Clock) : Auth::InstallationPatch
    now = clock.now
    bot = if (access = @access_token) && (subject = @bot_user_id) && (scope = @scope)
            Auth::Grant.new(subject, Auth::Secret.new(access), Auth::ResponseParser.scopes(scope),
              @expires_in.try { |seconds| now + seconds.seconds },
              @refresh_token.try { |token| Auth::Secret.new(token) })
          end
    users = {} of String => Auth::Grant
    if user = @authed_user
      if (access = user.access_token) && (scope = user.scope)
        users[user.id] = Auth::Grant.new(user.id, Auth::Secret.new(access), Auth::ResponseParser.scopes(scope),
          user.expires_in.try { |seconds| now + seconds.seconds },
          user.refresh_token.try { |token| Auth::Secret.new(token) })
      end
    end
    Auth::InstallationPatch.new(bot, users, @incoming_webhook)
  end

  def inspect(io : IO) : Nil
    io << "Slack::AuthResponse([REDACTED])"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end
end
