require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineDatetimePickerExample
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

  def self.run(output : IO = STDOUT) : Nil
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport
    proposed = Time.utc(2028, 2, 29, 16, 30)
    message = UI.message(fallback_text: "Propose a meeting start") do |builder|
      builder.actions({UI::BlockElements::DatetimePicker.new(action_id: "start", initial_date_time: proposed)},
        block_id: "meeting")
    end
    Slack::Api::ChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC",
      message: message, transport: OfflineExample::WebMockTransport.new).call

    # Independent incoming payloads. A chosen instant does not create a scheduled job.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"datetimepicker","block_id":"meeting","action_id":"start","selected_date_time":1835454600}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::DatetimePickerAction
        seconds = action.selected_date_time || raise "Absent or cleared start"
        start = Time.unix(seconds)
        # Real handlers must return each acknowledgment within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Proposed start: #{start.to_rfc3339} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Meeting"), submit: UI.plain("Save"), callback_id: "meeting") do |builder|
          builder.input(label: UI.plain("Start"), block_id: "meeting.start",
            element: UI::BlockElements::DatetimePicker.new(action_id: "start", initial_date_time: start, focus_on_load: true))
        end
        Slack::Api::ViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger,
          view: view, transport: OfflineExample::WebMockTransport.new).call
      else
        raise "Expected datetime choice"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"callback_id":"meeting","state":{"values":{"meeting.start":{"start":{"type":"datetimepicker","selected_date_time":1835458200}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.datetime_picker_value?("meeting.start", "start") || raise "Missing start state"
      seconds = state.selected_date_time || raise "Absent or cleared start"
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved start: #{Time.unix(seconds).to_rfc3339} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      picker = wire["blocks"][0]["elements"][0]
      raise "Expected datetime picker" unless picker["type"].as_s == "datetimepicker"
      raise "Expected Unix seconds" unless picker["initial_date_time"].as_i64 == 1835454600
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: wire}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      picker = wire["view"]["blocks"][0]["element"]
      raise "Expected datetime picker" unless picker["type"].as_s == "datetimepicker"
      raise "Expected chosen start" unless picker["initial_date_time"].as_i64 == 1835454600
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
