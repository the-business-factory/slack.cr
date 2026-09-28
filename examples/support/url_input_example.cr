require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineUrlInputExample
  alias UI = Slack::UI

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
  end

  # URL input is modal-only in Slack, so the form opens from a button action.
  # Returns the views.open request body and the submission acknowledgments in order.
  def self.run(output : IO = STDOUT) : {JSON::Any, Array(HTTP::Client::Response)}
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    requests = install_transport

    # Independent incoming payloads, not derived from the outbound form.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"button","block_id":"report","action_id":"report_bug","value":"bug"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    trigger = interaction.trigger_id || raise "Missing trigger"
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
    view = UI.form_modal(title: UI.plain("Report a bug"), submit: UI.plain("Send"), callback_id: "bug_report") do |builder|
      builder.input(label: UI.plain("Summary"), block_id: "bug.summary",
        element: UI::BlockElements::PlainTextInput.new(action_id: "summary"))
      builder.input(label: UI.plain("Page link"), block_id: "bug.link", dispatch_action: true,
        element: UI::BlockElements::UrlInput.new(action_id: "page", placeholder: UI.plain("https://"),
          dispatch_action_config: config, focus_on_load: true))
    end
    Slack::Api::ViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger,
      view: view, transport: OfflineExample::WebMockTransport.new).call

    payload = %({"type":"block_actions","team":null,"actions":[{"type":"url_text_input","block_id":"bug.link","action_id":"page","value":"http://intranet.example/wiki"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    case action = interaction.decoded_actions.first
    when Slack::Interactions::UrlInputAction
      # Real handlers must return each acknowledgment within three seconds.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Link entered: #{action.value || "none"} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected URL input action"
    end

    acknowledgements = ["http://intranet.example/wiki", "https://status.example.com/incident/7"].map do |link|
      payload = %({"type":"view_submission","team":null,"view":{"callback_id":"bug_report","state":{"values":{"bug.summary":{"summary":{"type":"plain_text_input","value":"Login fails"}},"bug.link":{"page":{"type":"url_text_input","value":"#{link}"}}}}}})
      interaction = receive(payload)
      raise "Expected submission" unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      acknowledge(interaction.state_map, output)
    end
    {requests.first, acknowledgements}
  end

  # Slack checks that the entry is a URL. Application rules, such as
  # HTTPS only, stay in the application. An empty HTTP 200 closes the view.
  def self.acknowledge(state : Slack::Interactions::StateMap, output : IO) : HTTP::Client::Response
    link = state.url_input_value?("bug.link", "page").try(&.value)
    uri = link.try { |value| URI.parse(value) }
    unless link && uri && uri.scheme == "https"
      errors = Slack::Interactions::ModalErrors.new({"bug.link" => "Enter an HTTPS link."})
      output.puts "Rejected link: #{link || "none"}"
      return HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: errors.to_json)
    end
    output.puts "Reported \"#{state.plain_text?("bug.summary", "summary")}\" at #{uri.host}"
    HTTP::Client::Response.new(200, body: "")
  end

  private def self.install_transport : Array(JSON::Any)
    requests = [] of JSON::Any
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      requests << wire
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
    requests
  end
end
