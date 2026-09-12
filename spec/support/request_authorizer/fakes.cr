require "../../../src/slack/auth/storage/memory_installation_store"

module RequestAuthorizerSupport
  FIXTURE_DIRECTORY = "spec/fixtures/request_authorizer"

  class Clock < Slack::Auth::Clock
    property now : Time

    def initialize(@now : Time = Time.unix(1_789_232_400))
    end
  end

  class Store < Slack::Auth::MemoryInstallationStore
    getter acquire_count : Int32 = 0
    getter dispatch_count : Int32 = 0
    getter fetch_count : Int32 = 0
    property acquire_failure : Slack::Auth::ErrorCode?
    property dispatch_failure : Slack::Auth::ErrorCode?

    def fetch(key : Slack::Auth::InstallationKey) : Slack::Auth::InstallationRecord?
      @fetch_count += 1
      super(key)
    end

    def acquire(query : Slack::Auth::InstallationQuery) : Slack::Auth::CredentialReference
      @acquire_count += 1
      if failure = @acquire_failure
        raise Slack::Auth::ContractError.new(failure)
      end
      super(query)
    end

    def credential_for_dispatch(reference : Slack::Auth::CredentialReference) : Slack::Auth::Secret
      @dispatch_count += 1
      if failure = @dispatch_failure
        raise Slack::Auth::ContractError.new(failure)
      end
      super(reference)
    end
  end

  class Transport < Slack::Auth::Transport
    getter requests = [] of Slack::Auth::TransportRequest
    @responses = [] of Slack::Auth::TransportResponse

    def enqueue(body : String, status : Int32 = 200,
                headers : HTTP::Headers = HTTP::Headers.new) : Nil
      @responses << Slack::Auth::TransportResponse.new(status, headers, body)
    end

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      @requests << request
      @responses.shift? || Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":true}))
    end
  end

  def self.fixture(name : String) : String
    File.read("#{FIXTURE_DIRECTORY}/#{name}")
  end

  def self.workspace_key(team_id : String = "T1", enterprise_id : String? = nil) : Slack::Auth::InstallationKey
    Slack::Auth::InstallationKey.new("A1", :workspace, enterprise_id: enterprise_id, team_id: team_id)
  end

  def self.org_key : Slack::Auth::InstallationKey
    Slack::Auth::InstallationKey.new("A1", :organization, enterprise_id: "E_ORG")
  end

  def self.grant(subject : String, token : String, expires_at : Time? = nil) : Slack::Auth::Grant
    Slack::Auth::Grant.new(subject, Slack::Auth::Secret.new(token), [] of String, expires_at: expires_at)
  end

  def self.seed(store : Slack::Auth::InstallationStore, key : Slack::Auth::InstallationKey,
                bot_token : String = "bot-token",
                bot_subject : String = "U_BOT") : Slack::Auth::InstallationRecord
    store.store(key, Slack::Auth::InstallationPatch.new(
      bot: grant(bot_subject, bot_token),
      users: {
        "U_ACTOR"     => grant("U_ACTOR", "actor-token"),
        "U_INSTALLER" => grant("U_INSTALLER", "installer-token"),
      }), nil)
  end

  def self.command_body(team_id : String? = "T1", enterprise_id : String? = nil,
                        enterprise_install : String? = "false", app_id : String = "A1") : String
    values = {
      "api_app_id"   => app_id,
      "channel_id"   => "C1",
      "channel_name" => "general",
      "command"      => "/authorize",
      "response_url" => "https://hooks.slack.test/response/synthetic",
      "team_name"    => "Workspace One",
      "text"         => "synthetic",
      "trigger_id"   => "synthetic-trigger",
      "user_id"      => "U_ACTOR",
      "user_name"    => "actor",
    }
    values["team_id"] = team_id if team_id
    values["enterprise_id"] = enterprise_id if enterprise_id
    values["is_enterprise_install"] = enterprise_install if enterprise_install
    URI::Params.encode(values)
  end
end
