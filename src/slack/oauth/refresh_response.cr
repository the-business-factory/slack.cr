require "./response_parser"

# A refresh response has credentials but need not include installation identity.
struct Slack::RefreshResponse
  getter access_token : String
  getter refresh_token : String
  getter expires_in : Int32
  getter scope : String
  getter token_type : String
  getter bot_user_id : String?

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
    @token_type = parser.required_string("token_type")
    parser.invalid! unless {"bot", "user"}.includes?(@token_type)
    @access_token = parser.required_string("access_token")
    @refresh_token = parser.required_string("refresh_token")
    @expires_in = parser.expiry || parser.invalid!
    @scope = parser.required_string("scope")
    @bot_user_id = parser.string("bot_user_id")
  end

  # Subject identity comes from the stored grant, never from an absent wire ID.
  def grant(previous : Auth::Grant, kind : Auth::TokenKind, clock : Auth::Clock) : Auth::Grant
    expected_type = kind.bot? ? "bot" : "user"
    if @token_type != expected_type || (kind.bot? && @bot_user_id && @bot_user_id != previous.subject_id)
      raise Auth::ResponseError.new
    end
    Auth::Grant.new(previous.subject_id, Auth::Secret.new(@access_token), Auth::ResponseParser.scopes(@scope),
      clock.now + @expires_in.seconds, Auth::Secret.new(@refresh_token))
  end

  def inspect(io : IO) : Nil
    io << "Slack::RefreshResponse([REDACTED])"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end
end
