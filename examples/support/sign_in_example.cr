require "../../src/slack"
require "../../src/slack/testing"

# Signs a person in with Slack, then rejects an ID token with a bad signature.
# The token and key set are the synthetic fixtures in spec/fixtures/oidc; the
# fixed clock is inside the token's five-minute lifetime.
module OfflineSignInExample
  FIXTURES = File.join(__DIR__, "../../spec/fixtures/oidc")
  SESSION  = Slack::Auth::Secret.new("trusted-session-binding")

  class FixedClock < Slack::Auth::Clock
    def now : Time
      Time.unix(1_760_000_060)
    end
  end

  # Returns the transport, which recorded the token exchanges and the key set fetch.
  def self.run(output : IO = STDOUT) : Slack::Testing::RecordingTransport
    configuration = Slack::OIDC::Configuration.new("1234.5678", Slack::Auth::Secret.new("synthetic-secret"),
      URI.parse("https://app.example.test/slack/sign-in/callback"))
    clock = FixedClock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = Slack::Testing::RecordingTransport.new
    handler = Slack::OIDC::SignInHandler.new(configuration, store, transport, clock: clock)

    # Route 1: send the browser to Slack.
    redirect = URI.parse(handler.redirect_url(SESSION))
    output.puts "Redirect to #{redirect.host}#{redirect.path} for #{redirect.query_params["scope"]}"

    # Route 2: Slack sends the browser back with a code and the state.
    # The fixture token carries a fixed nonce, so this attempt stands in for the round trip.
    seed(store, clock, "synthetic-state")
    transport.respond(token_response(fixture("id_token_valid.txt")))
    transport.respond(fixture("jwks.json"))
    sign_in = handler.authenticate_user(callback("synthetic-state"), SESSION)
    identity = sign_in.identity
    output.puts "Signed in #{identity.user_id} from #{identity.team_id} (#{identity.email})"

    seed(store, clock, "second-state")
    transport.respond(token_response(tampered(fixture("id_token_valid.txt"))))
    begin
      handler.authenticate_user(callback("second-state"), SESSION)
    rescue error : Slack::Auth::ContractError
      raise error unless error.code.verification_failed?
      output.puts "Rejected an ID token with a bad signature"
    end
    transport
  end

  private def self.seed(store : Slack::Auth::StateStore, clock : Slack::Auth::Clock, state : String) : Nil
    store.issue(Slack::Auth::AuthorizationAttempt.new(Slack::Auth::Secret.new(state), SESSION,
      Slack::Auth::AuthorizationPurpose::OIDC, clock.now + 10.minutes,
      "https://app.example.test/slack/sign-in/callback", Slack::Auth::Secret.new("synthetic-nonce")))
  end

  private def self.callback(state : String) : HTTP::Request
    HTTP::Request.new("GET", "/slack/sign-in/callback?code=synthetic-code&state=#{state}")
  end

  private def self.token_response(id_token : String) : String
    %({"ok":true,"access_token":"xoxp-synthetic-sign-in","token_type":"Bearer","id_token":"#{id_token}"})
  end

  # Changes the first signature character, so the signature no longer matches.
  private def self.tampered(token : String) : String
    signing_input, _, signature = token.rpartition('.')
    "#{signing_input}.#{signature[0] == 'A' ? 'B' : 'A'}#{signature[1..]}"
  end

  private def self.fixture(name : String) : String
    File.read(File.join(FIXTURES, name))
  end
end
