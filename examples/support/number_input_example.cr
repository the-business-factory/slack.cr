require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineNumberInputExample
  alias UI = Slack::UI::Checked

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
    }
    Slack.process_interaction(HTTP::Request.new("POST", "/interactions", headers, body))
  end

  # Number input is modal-only in Slack, so the form opens from a button action.
  # Returns the submission acknowledgments in the order they were received.
  def self.run(output : IO = STDOUT) : Array(HTTP::Client::Response)
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport

    # Independent incoming payloads, not derived from the outbound form.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"button","block_id":"booking","action_id":"book","value":"room-7"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    trigger = interaction.trigger_id || raise "Missing trigger"
    config = UI::CompositionObjects::DispatchActionConfig.new([UI::CompositionObjects::DispatchTrigger::OnEnterPressed])
    view = UI.form_modal(title: UI.plain("Book room 7"), submit: UI.plain("Book"), callback_id: "booking") do |builder|
      builder.input(label: UI.plain("Seats"), block_id: "booking.seats", dispatch_action: true,
        element: UI::BlockElements::NumberInput.new(is_decimal_allowed: false, action_id: "seats",
          initial_value: "2", min_value: "1", max_value: "12", dispatch_action_config: config, focus_on_load: true))
      builder.input(label: UI.plain("Budget"), block_id: "booking.budget", optional: true,
        element: UI::BlockElements::NumberInput.new(is_decimal_allowed: true, action_id: "budget"))
    end
    Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger,
      view: view, transport: OfflineExample::WebMockTransport.new).call

    payload = %({"type":"block_actions","team":null,"actions":[{"type":"number_input","block_id":"booking.seats","action_id":"seats","value":"14"}]})
    interaction = receive(payload)
    raise "Expected block action" unless interaction.is_a?(Slack::Interactions::BlockAction)
    case action = interaction.decoded_actions.first
    when Slack::Interactions::NumberInputAction
      # Real handlers must return each acknowledgment within three seconds.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Seats entered: #{action.value || "none"} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected number input action"
    end

    {"14" => nil, "4" => "12.50"}.map do |seats, budget|
      budget_field = budget ? %("value":"#{budget}") : %("value":null)
      payload = %({"type":"view_submission","team":null,"view":{"callback_id":"booking","state":{"values":{"booking.seats":{"seats":{"type":"number_input","value":"#{seats}"}},"booking.budget":{"budget":{"type":"number_input",#{budget_field}}}}}}})
      interaction = receive(payload)
      raise "Expected submission" unless interaction.is_a?(Slack::Interactions::ViewSubmission)
      acknowledge(interaction.state_map, output)
    end
  end

  # Element limits do not replace application checks. Parse and check
  # the received strings before you store them. An empty HTTP 200 closes the view.
  def self.acknowledge(state : Slack::Interactions::StateMap, output : IO) : HTTP::Client::Response
    seats = state.number_input_value?("booking.seats", "seats").try(&.value).try(&.to_i?)
    unless seats && (1..12).includes?(seats)
      errors = Slack::Interactions::ModalErrors.new({"booking.seats" => "Enter from 1 to 12 seats."})
      output.puts "Rejected seats: #{seats || "not a whole number"}"
      return HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "application/json"}, body: errors.to_json)
    end
    budget = state.number_input_value?("booking.budget", "budget").try(&.value) || "no"
    output.puts "Booked #{seats} seats with #{budget} budget"
    HTTP::Client::Response.new(200, body: "")
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      seats = wire["view"]["blocks"][0]["element"]
      raise "Expected whole-number input" unless seats["type"].as_s == "number_input" && seats["is_decimal_allowed"].as_bool == false
      raise "Expected string range" unless seats["min_value"].as_s == "1" && seats["max_value"].as_s == "12"
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
