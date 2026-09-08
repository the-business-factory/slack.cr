require "./spec_helper"
require "../src/slack/oauth/auth_response"
require "../src/slack/oauth/refresh_response"
require "./support/auth/protocol_store"
require "./support/auth/read_failing_io"

class ResponseClock < Slack::Auth::Clock
  getter calls : Int32 = 0

  def now : Time
    @calls += 1
    Time.utc(2026, 1, 1)
  end
end

def response_fixture(name : String) : String
  File.read("#{__DIR__}/fixtures/oauth_responses/#{name}.json")
end

def changed_response(name : String, & : Hash(String, JSON::Any) ->) : String
  data = JSON.parse(response_fixture(name)).as_h
  yield data
  data.to_json
end

def response_error(body : String, status : Int32 = 200, headers : HTTP::Headers = HTTP::Headers.new) : Slack::Auth::ResponseError
  expect_raises(Slack::Auth::ResponseError) { Slack::AuthResponse.parse(body, status, headers) }
end

{ {Slack::AuthResponse, "bot_workspace"}, {Slack::RefreshResponse, "refresh_bot"} }.each do |parser, fixture|
  describe "#{parser} input boundary" do
    it "rejects invalid UTF-8 with safe typed errors for text and streams" do
      {
        Bytes[0xff], Bytes[0x80], Bytes[0xc0, 0xaf], Bytes[0xe0, 0x80, 0xaf],
        Bytes[0xed, 0xa0, 0x80], Bytes[0xf4, 0x90, 0x80, 0x80], Bytes[0xe2, 0x82],
      }.each do |bytes|
        {"scope", "unknown_field"}.each do |field|
          body = changed_response(fixture) { |data| data[field] = JSON::Any.new("synthetic-encoding-marker") }
            .sub("synthetic-encoding-marker", "synthetic-encoding-secret#{String.new(bytes)}")
          {200, 503}.each do |status|
            [body, IO::Memory.new(body)].each do |input|
              error = expect_raises(Slack::Auth::ResponseError) do
                parser.parse(input, status, HTTP::Headers{"Retry-After" => "17", "X-Secret" => "synthetic-header-secret"})
              end
              error.code.should eq(Slack::Auth::ErrorCode::InvalidResponse)
              error.http_status.should eq(status)
              error.retry_after.should eq(17.seconds)
              error.slack_error.should be_nil
              error.cause.should be_nil
              {error.to_s, error.inspect, error.inspect_with_backtrace, error.pretty_inspect}.each do |text|
                text.should_not contain("synthetic-")
              end
            end
          end
        end
      end
    end

    it "normalizes valid two-, three- and four-byte UTF-8 without data loss" do
      body = changed_response(fixture) { |data| data["scope"] = JSON::Any.new("commands, café:read,チーム:read,🔐:read,café:read") }
      [body, IO::Memory.new(body)].each do |input|
        response = parser.parse(input)
        grant = if response.is_a?(Slack::AuthResponse)
                  response.installation_patch(ResponseClock.new).bot
                else
                  previous = Slack::Auth::Grant.new("UBOT", Slack::Auth::Secret.new("synthetic-old"), [] of String)
                  response.grant(previous, :bot, ResponseClock.new)
                end
        grant.try(&.scopes).should eq(["commands", "café:read", "チーム:read", "🔐:read"])
      end
    end

    it "parses a non-seekable pipe once without taking ownership of it" do
      body = changed_response(fixture) { |data| data["scope"] = JSON::Any.new("café,チーム,🔐") }
      IO.pipe do |reader, writer|
        # This small fixture fits in the pipe buffer; EOF needs no writer fiber.
        writer << body
        writer.close
        response = parser.from_json(reader)
        response.scope.should eq("café,チーム,🔐")
        reader.closed?.should be_false
        reader.read_byte.should be_nil
      end
    end

    it "normalizes a failure after a partial stream read without retaining its cause" do
      {200, 503}.each do |status|
        error = expect_raises(Slack::Auth::ResponseError) do
          parser.parse(AuthSupport::ReadFailingIO.new, status, HTTP::Headers{"Retry-After" => "9"})
        end
        error.code.should eq(Slack::Auth::ErrorCode::InvalidResponse)
        error.http_status.should eq(status)
        error.retry_after.should eq(9.seconds)
        error.slack_error.should be_nil
        error.cause.should be_nil
        {error.to_s, error.inspect, error.inspect_with_backtrace, error.pretty_inspect}.each do |text|
          text.should_not contain("synthetic-")
        end
      end
    end
  end
end

describe Slack::AuthResponse do
  it "normalizes bot-only, user-only and combined grants with String and IO parity" do
    {
      {"bot_workspace", Slack::Auth::InstallationKind::Workspace, "TTEAM", true, false},
      {"user_workspace", Slack::Auth::InstallationKind::Workspace, "TTEAM", false, true},
      {"combined_rotating", Slack::Auth::InstallationKind::Workspace, "TTEAM", true, true},
      {"bot_org_absent_team", Slack::Auth::InstallationKind::Organization, nil, true, false},
      {"user_org_null_team", Slack::Auth::InstallationKind::Organization, nil, false, true},
    }.each do |name, kind, team_id, has_bot, has_user|
      body = response_fixture(name)
      [body, IO::Memory.new(body)].each do |input|
        response = Slack::AuthResponse.parse(input)
        response.app_id.should eq("AAPP")
        key = response.installation_key
        key.kind.should eq(kind)
        key.team_id.should eq(team_id)
        clock = ResponseClock.new
        patch = response.installation_patch(clock)
        clock.calls.should eq(1)
        patch.bot.nil?.should eq(!has_bot)
        patch.users.has_key?("UUSER").should eq(has_user)
        if bot = patch.bot
          bot.subject_id.should eq("UBOT")
          bot.scopes.should eq(["commands", "chat:write"])
          bot.access_token.value.should eq("synthetic-bot-access")
        end
      end
    end
  end

  it "retains separate rotation expiries and webhook metadata" do
    response = Slack::AuthResponse.from_json(IO::Memory.new(response_fixture("combined_rotating")))
    patch = response.installation_patch(ResponseClock.new)
    patch.bot.try(&.expires_at).should eq(Time.utc(2026, 1, 1) + 3600.seconds)
    patch.bot.try(&.refresh_token).try(&.value).should eq("synthetic-bot-refresh")
    patch.users["UUSER"].expires_at.should eq(Time.utc(2026, 1, 1) + 1800.seconds)
    patch.users["UUSER"].refresh_token.try(&.value).should eq("synthetic-user-refresh")
    patch.webhook.try(&.channel_id).should eq("CCHANNEL")
    patch.webhook.try(&.url.value).should eq("https://hooks.example.invalid/synthetic-webhook")
    patch.webhook.try(&.configuration_url).try(&.value).should eq("https://example.invalid/synthetic-configuration")
  end

  it "allows optional names, null enterprise and identity-only authed user" do
    body = changed_response("bot_workspace") do |data|
      data["authed_user"] = JSON.parse(%({"id":"UINSTALLER"}))
      data["enterprise"] = JSON.parse("null")
    end
    response = Slack::AuthResponse.parse(body)
    response.team.try(&.name).should be_nil
    response.enterprise.should be_nil
    response.authed_user.try(&.id).should eq("UINSTALLER")
    response.installation_patch(ResponseClock.new).users.should be_empty
  end

  it "keeps an organization visible team outside the installation key" do
    body = changed_response("bot_org_absent_team") { |data| data["team"] = JSON.parse(%({"id":"TVISIBLE","name":"Visible"})) }
    response = Slack::AuthResponse.parse(body)
    response.team.try(&.id).should eq("TVISIBLE")
    response.installation_key.team_id.should be_nil
    response.installation_key.enterprise_id.should eq("EORG")
  end

  it "rejects missing required bot fields and malformed known fields" do
    {"app_id", "access_token", "token_type", "scope", "bot_user_id", "team"}.each do |field|
      response_error(changed_response("bot_workspace", &.delete(field)))
    end
    {"app_id" => "null", "access_token" => "\"\"", "scope" => "12", "team" => "[]"}.each do |field, value|
      response_error(changed_response("bot_workspace") { |data| data[field] = JSON.parse(value) })
    end
  end

  it "rejects incomplete organization, user and webhook identities" do
    response_error(changed_response("bot_org_absent_team") { |data| data.delete("enterprise") })
    {"id", "access_token", "scope", "token_type"}.each do |field|
      body = changed_response("user_workspace") { |data| data["authed_user"].as_h.delete(field) }
      response_error(body)
    end
    {"url", "channel_id"}.each do |field|
      body = changed_response("combined_rotating") { |data| data["incoming_webhook"].as_h.delete(field) }
      response_error(body)
    end
  end

  it "rejects invalid rotation fields and token kinds" do
    {"0", "-1", "1.5", "2147483648", "\"3600\""}.each do |value|
      response_error(changed_response("combined_rotating") { |data| data["expires_in"] = JSON.parse(value) })
    end
    {"refresh_token", "expires_in"}.each do |field|
      response_error(changed_response("combined_rotating") { |data| data.delete(field) })
    end
    response_error(changed_response("bot_workspace") { |data| data["token_type"] = JSON::Any.new("user") })
    response_error(changed_response("bot_workspace") { |data| data["is_enterprise_install"] = JSON.parse("null") })
  end

  it "normalizes API and malformed input errors identically for strings and streams" do
    {"{", "[]", "null", "{}", %({"ok":false}), %({"ok":"true"}), %({"ok":true})}.each do |body|
      [body, IO::Memory.new(body)].each do |input|
        error = expect_raises(Slack::Auth::ResponseError) { Slack::AuthResponse.parse(input) }
        error.code.should eq(Slack::Auth::ErrorCode::InvalidResponse)
        error.http_status.should eq(200)
        error.cause.should be_nil
      end
    end
    error = response_error(%({"ok":false,"error":"invalid_code"}))
    error.code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
    error.slack_error.should eq("invalid_code")
    response_error(%({"error":"invalid_code"})).code.should eq(Slack::Auth::ErrorCode::InvalidResponse)
    response_error(%({"ok":false,"error":"invalid_refresh_token"}), 400).code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
  end

  it "keeps remote secrets out of failures and response display" do
    canary = "synthetic-secret-canary"
    error = response_error(%({"ok":false,"error":"#{canary}","access_token":"#{canary}"}))
    error.slack_error.should be_nil
    {error.to_s, error.inspect, error.inspect_with_backtrace}.each(&.should_not(contain(canary)))
    response = Slack::AuthResponse.parse(response_fixture("combined_rotating"))
    {response.inspect, response.to_s, response.authed_user.inspect, response.installation_patch(ResponseClock.new).inspect}.each do |text|
      text.should_not contain("synthetic-")
    end
  end

  it "handles non-JSON HTTP failures and safe retry metadata for strings and streams" do
    {429, 503, 302}.each do |status|
      ["<html>secret</html>", IO::Memory.new("<html>secret</html>")].each do |body|
        error = expect_raises(Slack::Auth::ResponseError) do
          Slack::AuthResponse.parse(body, status, HTTP::Headers{"Retry-After" => "30"})
        end
        error.http_status.should eq(status)
        error.retry_after.should eq(30.seconds)
        error.to_s.should_not contain("secret")
      end
    end
    {"-1", "invalid", "99999999999999999999999999"}.each do |value|
      response_error("", 429, HTTP::Headers{"Retry-After" => value}).retry_after.should be_nil
    end
    response_error("", 429).retry_after.should be_nil
  end

  it "accepts a transport response and normalizes duplicate scopes" do
    body = changed_response("bot_workspace") { |data| data["scope"] = JSON::Any.new("commands, chat:write,commands") }
    wire = Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, body)
    Slack::AuthResponse.parse(wire).installation_patch(ResponseClock.new).bot.try(&.scopes).should eq(["commands", "chat:write"])
  end

  it "preserves the stored bot, other users and webhook on a user-only authorization" do
    clock = ResponseClock.new
    store = AuthSupport::ProtocolStore.new(clock)
    original = Slack::AuthResponse.parse(response_fixture("combined_rotating"))
    key = original.installation_key
    record = store.store(key, original.installation_patch(clock), nil)
    other = Slack::Auth::Grant.new("UOTHER", Slack::Auth::Secret.new("synthetic-other"), ["search:read"])
    record = store.store(key, Slack::Auth::InstallationPatch.new(users: {"UOTHER" => other}), record.version)
    body = changed_response("user_workspace") do |data|
      data["authed_user"].as_h["access_token"] = JSON::Any.new("synthetic-reauthorized-user")
    end
    response = Slack::AuthResponse.parse(body)
    response.installation_key.should eq(key)

    updated = store.store(key, response.installation_patch(clock), record.version)
    updated.bot.should eq(record.bot)
    updated.users["UOTHER"].should eq(record.users["UOTHER"])
    updated.webhook.should eq(record.webhook)
    updated.users.keys.sort!.should eq(["UOTHER", "UUSER"])
    updated.users["UUSER"].revision.should be > record.users["UUSER"].revision
    updated.users["UUSER"].grant.access_token.value.should eq("synthetic-reauthorized-user")
    updated.users["UUSER"].grant.refresh_token.should be_nil
    updated.users["UUSER"].grant.expires_at.should be_nil
  end
end

describe Slack::RefreshResponse do
  it "normalizes bot and user refreshes using the trusted previous subject" do
    {Slack::Auth::TokenKind::Bot, Slack::Auth::TokenKind::User}.each do |kind|
      name = kind.bot? ? "refresh_bot" : "refresh_user"
      previous = Slack::Auth::Grant.new("UTRUSTED", Slack::Auth::Secret.new("synthetic-old"), ["old-scope"],
        Time.utc(2025, 12, 31), Slack::Auth::Secret.new("synthetic-old-refresh"))
      body = response_fixture(name)
      [body, IO::Memory.new(body)].each do |input|
        response = Slack::RefreshResponse.parse(input)
        grant = response.grant(previous, kind, ResponseClock.new)
        grant.subject_id.should eq("UTRUSTED")
        grant.access_token.value.should eq(kind.bot? ? "synthetic-next-bot" : "synthetic-next-user")
        grant.expires_at.should eq(Time.utc(2026, 1, 1) + (kind.bot? ? 3600 : 1800).seconds)
        grant.refresh_token.try(&.value).should eq(kind.bot? ? "synthetic-next-refresh" : "synthetic-next-user-refresh")
        grant.scopes.should eq(kind.bot? ? ["commands", "chat:write"] : ["search:read"])
        response.inspect.should_not contain("synthetic-")
      end
    end
  end

  it "preserves safe rejection and HTTP retry metadata through the refresh API" do
    {
      { %({"ok":false,"error":"invalid_refresh_token"}), 400, Slack::Auth::ErrorCode::ReauthorizationRequired, "invalid_refresh_token" },
      { %({"ok":false,"error":"ratelimited"}), 429, Slack::Auth::ErrorCode::InvalidResponse, "ratelimited" },
      { %({"ok":false,"error":"synthetic-remote-secret"}), 503, Slack::Auth::ErrorCode::InvalidResponse, nil },
      {response_fixture("refresh_bot"), 503, Slack::Auth::ErrorCode::InvalidResponse, nil},
      {"<html>synthetic-remote-secret</html>", 502, Slack::Auth::ErrorCode::InvalidResponse, nil},
    }.each do |body, status, code, slack_error|
      [body, IO::Memory.new(body)].each do |input|
        error = expect_raises(Slack::Auth::ResponseError) do
          Slack::RefreshResponse.parse(input, status, HTTP::Headers{"Retry-After" => "30"})
        end
        error.code.should eq(code)
        error.http_status.should eq(status)
        error.retry_after.should eq(30.seconds)
        error.slack_error.should eq(slack_error)
        error.cause.should be_nil
        error.inspect_with_backtrace.should_not contain("synthetic-")
      end
    end
  end

  it "rejects incomplete refresh responses and installation parsing of a refresh" do
    {"access_token", "refresh_token", "expires_in", "scope", "token_type", "ok"}.each do |field|
      body = changed_response("refresh_bot", &.delete(field))
      expect_raises(Slack::Auth::ResponseError) { Slack::RefreshResponse.parse(body) }
    end
    response_error(response_fixture("refresh_bot"))
    expect_raises(Slack::Auth::ResponseError) { Slack::RefreshResponse.parse(response_fixture("bot_workspace")) }
  end

  it "rejects a different token kind or explicit bot subject" do
    previous = Slack::Auth::Grant.new("UTRUSTED", Slack::Auth::Secret.new("old"), [] of String)
    response = Slack::RefreshResponse.parse(response_fixture("refresh_bot"))
    expect_raises(Slack::Auth::ResponseError) { response.grant(previous, :user, ResponseClock.new) }
    body = changed_response("refresh_bot") { |data| data["bot_user_id"] = JSON::Any.new("UOTHER") }
    expect_raises(Slack::Auth::ResponseError) do
      Slack::RefreshResponse.parse(body).grant(previous, :bot, ResponseClock.new)
    end
  end
end
