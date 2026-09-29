require "../spec_helper"
require "../support/one_pass"

module ExternalSelectInteractionSpec
  alias UI = Slack::UI
  alias Response = Slack::Interactions::BlockSuggestionResponse

  def self.option(value : String) : UI::CompositionObjects::Option
    UI::CompositionObjects::Option.new(text: UI.plain(value.capitalize), value: value)
  end

  def self.signed_request(payload : String, secret : String = "synthetic-signing-secret") : HTTP::Request
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    signature = OpenSSL::HMAC.hexdigest(:sha256, secret, "v0:#{timestamp}:#{body}")
    headers = HTTP::Headers{"X-Slack-Request-Timestamp" => timestamp, "X-Slack-Signature" => "v0=#{signature}"}
    HTTP::Request.new("POST", "/options", headers, body)
  end

  def self.receive(request : HTTP::Request) : Slack::Interaction
    verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new("synthetic-signing-secret"))
    Slack::Interactions.parse(verifier.verify(request).body)
  end

  # Based on Slack's documented message-surface block_suggestion example.
  MESSAGE_SUGGESTION = <<-JSON
    {"type":"block_suggestion","user":{"id":"U-SYNTHETIC","username":"sam","name":"sam","team_id":"E-ORG"},
     "container":{"type":"message","message_ts":"1628851405.000300","channel_id":"C-SYNTHETIC","is_ephemeral":false},
     "api_app_id":"A-SYNTHETIC","token":"synthetic-verification-token","action_id":"location","block_id":"bK6","value":"tes",
     "team":{"id":"T-SYNTHETIC","domain":"example","enterprise_id":"E-ORG","enterprise_name":"example-org"},
     "enterprise":{"id":"E-ORG","name":"example-org"},"is_enterprise_install":false,
     "channel":{"id":"C-SYNTHETIC","name":"general"},
     "message":{"type":"message","ts":"1628851405.000300","blocks":[{"type":"input","block_id":"bK6","element":{"type":"external_select","action_id":"location"}}]}}
    JSON

  describe "received block suggestions" do
    it "parses a signed message suggestion into typed IDs, query, and source" do
      suggestion = receive(signed_request(MESSAGE_SUGGESTION)).should be_a(Slack::Interactions::BlockSuggestion)
      suggestion.type.should eq "block_suggestion"
      suggestion.action_id.should eq "location"
      suggestion.block_id.should eq "bK6"
      suggestion.value.should eq "tes"
      suggestion.api_app_id.should eq "A-SYNTHETIC"
      suggestion.token.should eq "synthetic-verification-token"
      suggestion.user.should_not(be_nil).id.should eq "U-SYNTHETIC"
      suggestion.team.should_not(be_nil).enterprise_id.should eq "E-ORG"
      suggestion.enterprise.should_not(be_nil).id.should eq "E-ORG"
      suggestion.container.should_not(be_nil)["channel_id"].as_s.should eq "C-SYNTHETIC"
      suggestion.channel.should_not(be_nil)["name"].as_s.should eq "general"
      suggestion.message.should_not(be_nil)["ts"].as_s.should eq "1628851405.000300"
      suggestion.view.should be_nil
    end

    it "parses a modal suggestion with an empty query and its view" do
      payload = <<-JSON
        {"type":"block_suggestion","team":{"id":"T-SYNTHETIC","domain":"example"},"enterprise":null,
        "user":{"id":"U-SYNTHETIC","name":"sam","team_id":"T-SYNTHETIC"},"container":{"type":"view","view_id":"V-SYNTHETIC"},
        "view":{"id":"V-SYNTHETIC","type":"modal","app_installed_team_id":"T-SYNTHETIC","state":{"values":{}},"callback_id":"assign"},
        "api_app_id":"A-SYNTHETIC","action_id":"project","block_id":"assignment","value":""}
        JSON
      suggestion = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::BlockSuggestion)
      suggestion.value.should eq ""
      suggestion.enterprise.should be_nil
      suggestion.message.should be_nil
      view = suggestion.view.should_not be_nil
      view.app_installed_team_id.should eq "T-SYNTHETIC"
      view.callback_id.should eq "assign"
    end

    it "verifies request bytes before parsing a malformed suggestion" do
      request = signed_request(%({"type":"block_suggestion"}), secret: "wrong-secret")
      expect_raises(Slack::Errors::SignatureMismatch) { receive(request) }
    end

    it "rejects suggestions without string action, block, or query fields" do
      base = JSON.parse(MESSAGE_SUGGESTION).as_h
      {"action_id" => nil, "block_id" => nil, "value" => nil}.each_key do |field|
        missing = base.reject(field)
        expect_raises(JSON::SerializableError, /#{field}/) { receive(signed_request(missing.to_json)) }
        wrong = base.merge({field => JSON::Any.new(42_i64)})
        expect_raises(JSON::SerializableError) { receive(signed_request(wrong.to_json)) }
      end
      null_query = base.merge({"value" => JSON::Any.new(nil)})
      expect_raises(JSON::SerializableError) { Slack::Interaction.from_json(null_query.to_json) }
    end
  end

  describe Slack::Interactions::BlockSuggestionResponse do
    it "serializes independently authored option and option group bodies" do
      described = UI::CompositionObjects::Option.new(text: UI.plain("Apollo"), value: "apollo",
        description: UI.plain("Moon program"))
      JSON.parse(Response.new(options: {described, option("gemini")}).to_json).should eq JSON.parse(<<-JSON)
        {"options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo","description":{"type":"plain_text","text":"Moon program"}},
          {"text":{"type":"plain_text","text":"Gemini"},"value":"gemini"}]}
        JSON
      groups = {
        UI::CompositionObjects::OptionGroup.new(label: UI.plain("Active"), options: {option("apollo")}),
        UI::CompositionObjects::OptionGroup.new(label: UI.plain("Archived"), options: {option("mercury"), option("gemini")}),
      }
      JSON.parse(Response.new(option_groups: groups).to_json).should eq JSON.parse(<<-JSON)
        {"option_groups":[{"label":{"type":"plain_text","text":"Active"},"options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"}]},
          {"label":{"type":"plain_text","text":"Archived"},"options":[{"text":{"type":"plain_text","text":"Mercury"},"value":"mercury"},{"text":{"type":"plain_text","text":"Gemini"},"value":"gemini"}]}]}
        JSON
      JSON.parse(Response.new(options: [] of UI::CompositionObjects::Option).to_json).should eq JSON.parse(%({"options":[]}))
    end

    it "enforces the documented 100-item limits and unique values" do
      hundred = (1..100).map { |index| option("v#{index}") }
      Response.new(options: hundred).options.should_not(be_nil).size.should eq 100
      expect_raises(UI::ValidationError) { Response.new(options: hundred + [option("v101")]) }.issues.map(&.path).should eq ["options"]
      group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: {option("only")})
      duplicate = expect_raises(UI::ValidationError) { Response.new(options: {option("same"), option("same")}) }
      duplicate.issues.map(&.path).should eq ["options[1].value"]
      too_many = (1..101).map { |index| UI::CompositionObjects::OptionGroup.new(label: UI.plain("G#{index}"), options: {option("v#{index}")}) }
      expect_raises(UI::ValidationError) { Response.new(option_groups: too_many) }.issues.map(&.path).should eq ["option_groups"]
      across = expect_raises(UI::ValidationError) { Response.new(option_groups: {group, group}) }
      across.issues.map(&.path).should eq ["option_groups[1].options[0].value"]
    end

    it "owns options and groups after one traversal" do
      items = [option("apollo")]
      source = SpecSupport::OnePass.new(items)
      response = Response.new(options: source)
      items.clear
      response.options.should_not(be_nil).clear
      source.passes.should eq 1
      response.option_groups.should be_nil
      groups = [UI::CompositionObjects::OptionGroup.new(label: UI.plain("Active"), options: {option("apollo")})]
      grouped = Response.new(option_groups: SpecSupport::OnePass.new(groups))
      groups.clear
      grouped.option_groups.should_not(be_nil).clear
      grouped.options.should be_nil
      JSON.parse(response.to_json).should eq JSON.parse(%({"options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"}]}))
      JSON.parse(grouped.to_json)["option_groups"].as_a.size.should eq 1
    end
  end

  describe "received external selections" do
    it "decodes independent actions and state while preserving unknown data" do
      interaction = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::BlockAction)
        {"type":"block_actions","actions":[
          {"type":"external_select","block_id":"assignment","action_id":"project","action_ts":"1710000000.000001",
           "selected_option":{"text":{"type":"plain_text","text":"Apollo","emoji":true},"value":"apollo"},"future":false},
          {"type":"multi_external_select","block_id":"assignment","action_id":"projects",
           "selected_options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"},{"text":{"type":"plain_text","text":"Gemini"},"value":"gemini","description":{"type":"plain_text","text":"Two"}}]}],
         "state":{"values":{"assignment":{
          "project":{"type":"external_select","selected_option":{"text":{"type":"plain_text","text":"Mercury"},"value":"mercury"}},
          "projects":{"type":"multi_external_select","selected_options":[{"text":{"type":"plain_text","text":"Gemini"},"value":"gemini"}],"future":[]}}}}}
        JSON
      actions = interaction.actions
      single = actions[0].should be_a(Slack::Interactions::ExternalSelectAction)
      single.type.should eq "external_select"
      single.action_id.should eq "project"
      single.block_id.should eq "assignment"
      single.action_ts.should eq "1710000000.000001"
      selected = single.selected_option.should_not be_nil
      selected.value.should eq "apollo"
      selected.text.should eq "Apollo"
      multi = actions[1].should be_a(Slack::Interactions::MultiExternalSelectAction)
      multi.selected_options.should_not(be_nil).map(&.value).should eq ["apollo", "gemini"]
      multi.selected_options.should_not(be_nil).clear
      multi.selected_options.should_not(be_nil).size.should eq 2
      multi.action_ts.should be_nil
      state = interaction.state
      state.external_select_value?("assignment", "project").should_not(be_nil).selected_option.should_not(be_nil).value.should eq "mercury"
      projects = state.multi_external_select_value?("assignment", "projects").should_not be_nil
      projects.selected_options.should_not(be_nil).map(&.value).should eq ["gemini"]
    end

    it "distinguishes absent, null, and empty selections in actions and submissions" do
      {"external_select" => "selected_option", "multi_external_select" => "selected_options"}.each do |type, field|
        {"", "null", type == "external_select" ? %({"text":{"type":"plain_text","text":""},"value":""}) : "[]"}.each do |value|
          selection = value.empty? ? "" : %(,"#{field}":#{value})
          action = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"#{type}","block_id":"b","action_id":"a"#{selection}}]))).first
          payload = %({"type":"view_submission","view":{"state":{"values":{"b":{"a":{"type":"#{type}"#{selection}}}}}}})
          submission = Slack::Interaction.from_json(payload).should be_a(Slack::Interactions::ViewSubmission)
          expected = value.empty? ? Slack::Interactions::ValuePresence::Absent : value == "null" ? Slack::Interactions::ValuePresence::Null : Slack::Interactions::ValuePresence::Present
          case action
          when Slack::Interactions::ExternalSelectAction
            state = submission.state.external_select_value?("b", "a").should_not be_nil
            action.selected_option_presence.should eq expected
            state.selected_option_presence.should eq expected
            state.selected_option.try(&.value).should eq(expected.present? ? "" : nil)
          when Slack::Interactions::MultiExternalSelectAction
            state = submission.state.multi_external_select_value?("b", "a").should_not be_nil
            action.selected_options_presence.should eq expected
            state.selected_options_presence.should eq expected
            state.selected_options.try(&.size).should eq(expected.present? ? 0 : nil)
          else
            fail "Expected a typed external action"
          end
        end
      end
    end

    it "reports useful paths for malformed known action and state values" do
      {
        "external_select" => {
          %({"selected_option":[]})            => "selected_option",
          %({"selected_option":{"value":"v"}}) => "selected_option.text",
          %({"action_id":42})                  => "action_id",
        },
        "multi_external_select" => {
          %({"selected_options":{}})     => "selected_options",
          %({"selected_options":[null]}) => "selected_options[0]",
          %({"block_id":[]})             => "block_id",
        },
      }.each do |type, cases|
        cases.each do |override, suffix|
          raw = JSON.parse(%({"type":"#{type}","block_id":"b","action_id":"a"})).as_h.merge(JSON.parse(override).as_h)
          interaction = Slack::Interaction.from_json({type: "block_actions", actions: [raw]}.to_json).should be_a(Slack::Interactions::BlockAction)
          expect_raises(Slack::Interactions::TypeMismatch) { interaction.actions }.path.should eq "actions[0].#{suffix}"
          if suffix.starts_with?("selected_")
            map = Slack::Interactions::StateMap.new(JSON.parse({values: {b: {a: raw}}}.to_json))
            expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].#{suffix})
          end
        end
      end
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"single":{"type":"external_select"},"multi":{"type":"multi_external_select"}}}})))
      expect_raises(Slack::Interactions::TypeMismatch) { map.external_select_value?("b", "multi") }.path.should eq %(state.values["b"]["multi"])
      expect_raises(Slack::Interactions::TypeMismatch) { map.multi_external_select_value?("b", "single") }.path.should eq %(state.values["b"]["single"])
    end
  end
end
