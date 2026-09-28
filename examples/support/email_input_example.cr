require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineEmailInputExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  # Authored from Slack's email input, Input block, and views.open contracts, not from the serializer.
  EXPECTED_VIEW = <<-JSON
    {"type":"modal","title":{"type":"plain_text","text":"Invite a guest"},"submit":{"type":"plain_text","text":"Invite"},
     "callback_id":"invite","blocks":[
      {"type":"input","label":{"type":"plain_text","text":"Guest email"},"block_id":"invite.email","dispatch_action":true,
       "element":{"type":"email_text_input","action_id":"email","initial_value":"guest@partner.example",
        "dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},"focus_on_load":true,
        "placeholder":{"type":"plain_text","text":"name@partner.example"}}}]}
    JSON

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    Slack::Interactions.parse(VERIFIER.verify(HTTP::Request.new("POST", "/interactions", headers, body)).body)
  end

  # Email input is modal-only in Slack, so the form opens from a button action.
  # Returns the submission acknowledgments in the order they were received.
  def self.run(output : IO = STDOUT) : Array(HTTP::Client::Response)
    install_transport

    # Independent incoming payloads, not derived from the outbound form.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"button","block_id":"guests","action_id":"invite","value":"project-7"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    trigger = interaction.trigger_id || raise "Missing trigger"
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
    view = UI.form_modal(title: UI.plain("Invite a guest"), submit: UI.plain("Invite"), callback_id: "invite") do |builder|
      builder.input(label: UI.plain("Guest email"), block_id: "invite.email", dispatch_action: true,
        element: UI::BlockElements::EmailInput.new(action_id: "email", initial_value: "guest@partner.example",
          dispatch_action_config: config, focus_on_load: true, placeholder: UI.plain("name@partner.example")))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))

    payload = %({"type":"block_actions","team":null,"actions":[{"type":"email_text_input","block_id":"invite.email","action_id":"email","value":"lead@partner.example"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    case action = interaction.decoded_actions.first
    when Slack::Interactions::EmailInputAction
      # Real handlers must return each acknowledgment within three seconds.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Email entered: #{action.value || "none"} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected email input action"
    end

    ["lead@other.example", "lead@partner.example"].map do |email|
      payload = %({"type":"view_submission","team":null,"view":{"callback_id":"invite","state":{"values":{"invite.email":{"email":{"type":"email_text_input","value":"#{email}"}}}}}})
      interaction = receive(payload)
      raise "Expected submission" unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      acknowledge(interaction.state_map, output)
    end
  end

  # Slack does not apply application rules, such as an allowed domain.
  # Check the received address before you use it. An empty HTTP 200 closes the view.
  def self.acknowledge(state : Slack::Interactions::StateMap, output : IO) : HTTP::Client::Response
    email = state.email_input_value?("invite.email", "email").try(&.value)
    unless email && email.ends_with?("@partner.example")
      errors = Slack::Interactions::ModalErrors.new({"invite.email" => "Enter a partner.example address."})
      output.puts "Rejected email: #{email || "none"}"
      return HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: errors.to_json)
    end
    output.puts "Invited #{email}"
    HTTP::Client::Response.new(200, body: "")
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      raise "Unexpected email form" unless wire["view"] == JSON.parse(EXPECTED_VIEW)
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
