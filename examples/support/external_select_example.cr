require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineExternalSelectExample
  alias UI = Slack::UI::Checked

  PROJECTS = {"apollo" => "Apollo", "artemis" => "Artemis", "gemini" => "Gemini"}

  def self.signed(payload : String, path : String) : HTTP::Request
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/x-www-form-urlencoded",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    HTTP::Request.new("POST", path, headers, body)
  end

  # Handles a request to the app's Options Load URL. The application sends
  # this HTTP 200 JSON response to Slack within three seconds.
  def self.suggest(request : HTTP::Request) : HTTP::Client::Response
    suggestion = Slack.process_interaction(request)
    raise "Expected block suggestion" unless suggestion.is_a?(Slack::Interactions::BlockSuggestion)
    raise "Unexpected menu" unless suggestion.block_id == "assignment" && suggestion.action_id == "project"
    query = suggestion.value.downcase
    matches = PROJECTS.select { |_, label| label.downcase.starts_with?(query) }.map do |value, label|
      UI::CompositionObjects::Option.new(text: UI.plain(label), value: value)
    end
    HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"},
      body: Slack::Interactions::BlockSuggestionResponse.new(options: matches.first(100)).to_json)
  end

  # Returns the prepared suggestion response for inspection.
  def self.run(output : IO = STDOUT) : HTTP::Client::Response
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport
    message = UI.message(fallback_text: "Assign a project") do |builder|
      builder.section(UI.plain("Project"), block_id: "assignment",
        accessory: UI::BlockElements::ExternalSelect.new(action_id: "project",
          placeholder: UI.plain("Find a project"), min_query_length: 2))
    end
    Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call

    # Independently authored Slack payloads, not derived from outbound values.
    suggestion = %({"type":"block_suggestion","team":{"id":"T-SYNTHETIC","domain":"example"},"user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"api_app_id":"A-SYNTHETIC","container":{"type":"message","message_ts":"1710000000.000001","channel_id":"C-SYNTHETIC","is_ephemeral":false},"action_id":"project","block_id":"assignment","value":"a"})
    response = suggest(signed(suggestion, "/options"))
    output.puts "Suggested #{JSON.parse(response.body)["options"].as_a.size} projects (HTTP #{response.status_code})"

    selection = %({"type":"block_actions","team":{"id":"T-SYNTHETIC"},"trigger_id":"synthetic-trigger","actions":[{"type":"external_select","block_id":"assignment","action_id":"project","selected_option":{"text":{"type":"plain_text","text":"Artemis","emoji":true},"value":"artemis"},"action_ts":"1710000001.000001"}]})
    case interaction = Slack.process_interaction(signed(selection, "/interactions"))
    when Slack::Interactions::BlockAction
      action = interaction.decoded_actions.first
      raise "Expected project selection" unless action.is_a?(Slack::Interactions::ExternalSelectAction)
      project = action.selected_option || raise "Absent or null project"
      # Real handlers must acknowledge each interaction within three seconds.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Selected project: #{project.value} (acknowledged #{acknowledgement.status_code})"
      open_related_form(interaction.trigger_id || raise("Missing trigger"), project)
    else
      raise "Expected block action"
    end

    submission = %({"type":"view_submission","team":{"id":"T-SYNTHETIC"},"view":{"callback_id":"project.related","state":{"values":{"related":{"projects":{"type":"multi_external_select","selected_options":[{"text":{"type":"plain_text","text":"Artemis"},"value":"artemis"},{"text":{"type":"plain_text","text":"Gemini"},"value":"gemini"}]}}}}}})
    case interaction = Slack.process_interaction(signed(submission, "/interactions"))
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.multi_external_select_value?("related", "projects") || raise "Missing related state"
      related = state.selected_options || raise "Absent or null related projects"
      output.puts "Saved related projects: #{related.map(&.value).join(", ")} (acknowledged 200)"
    else
      raise "Expected submission"
    end
    response
  end

  private def self.open_related_form(trigger : String, project : Slack::Interactions::SelectedOption) : Nil
    view = UI.form_modal(title: UI.plain("Related projects"), submit: UI.plain("Save"), callback_id: "project.related") do |builder|
      builder.input(label: UI.plain("Related"), block_id: "related",
        element: UI::BlockElements::MultiExternalSelect.new(action_id: "projects", max_selected_items: 3,
          initial_options: {UI::CompositionObjects::Option.new(text: UI.plain(project.text), value: project.value)}))
    end
    Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger,
      view: view, transport: OfflineExample::WebMockTransport.new).call
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      control = wire["blocks"][0]["accessory"]
      raise "Missing project select" unless control["type"].as_s == "external_select" && control["min_query_length"].as_i == 2
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      control = wire["view"]["blocks"][0]["element"]
      raise "Missing related select" unless control["type"].as_s == "multi_external_select"
      raise "Missing initial project" unless control["initial_options"].as_a.map(&.["value"].as_s) == ["artemis"]
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
