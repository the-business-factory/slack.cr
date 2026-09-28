require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineDateTimePickersExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(SIGNING_SECRET, timestamp, body).compute,
    }
    Slack::Interactions.parse(VERIFIER.verify(HTTP::Request.new("POST", "/interactions", headers, body)).body)
  end

  def self.run(output : IO = STDOUT) : Nil
    install_transport
    message = UI.message(fallback_text: "Choose a date, then a time") do |builder|
      builder.section(UI.plain("Choose a date"), block_id: "schedule",
        accessory: UI::BlockElements::DatePicker.new(action_id: "date", initial_date: "2028-02-29"))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Independent incoming payloads. These choices do not create a scheduled job.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"datepicker","block_id":"schedule","action_id":"date","selected_date":"2028-02-29"}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::DatePickerAction
        date = action.selected_date || raise "Absent or cleared date"
        # Real handlers must return each acknowledgment within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Chosen date: #{date} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Schedule"), submit: UI.plain("Save"), callback_id: "schedule") do |builder|
          builder.input(label: UI.plain("Date"), block_id: "schedule.date",
            element: UI::BlockElements::DatePicker.new(action_id: "date", initial_date: date))
          builder.input(label: UI.plain("Time"), block_id: "schedule.time",
            element: UI::BlockElements::TimePicker.new(action_id: "time", initial_time: "09:00",
              timezone: "America/Chicago", focus_on_load: true))
        end
        client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))
      else
        raise "Expected date choice"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"callback_id":"schedule","state":{"values":{"schedule.date":{"date":{"type":"datepicker","selected_date":"2028-03-01"}},"schedule.time":{"time":{"type":"timepicker","selected_time":"09:30","timezone":"America/Chicago"}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      date_state = interaction.state_map.date_picker_value?("schedule.date", "date") || raise "Missing date state"
      time_state = interaction.state_map.time_picker_value?("schedule.time", "time") || raise "Missing time state"
      date = date_state.selected_date || raise "Absent or cleared date"
      time = time_state.selected_time || raise "Absent or cleared time"
      timezone = time_state.timezone || raise "Missing timezone for this application"
      # Application storage can retain the three strings. Resolving a timezone or
      # an ambiguous local time to an instant is a separate application decision.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved choice: #{date} at #{time} (#{timezone}; acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      raise "Expected date picker" unless wire["blocks"][0]["accessory"]["type"].as_s == "datepicker"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      date = wire["view"]["blocks"][0]["element"]
      time = wire["view"]["blocks"][1]["element"]
      raise "Expected chosen date" unless date["initial_date"].as_s == "2028-02-29"
      raise "Expected time picker" unless time["type"].as_s == "timepicker"
      raise "Expected timezone hint" unless time["timezone"].as_s == "America/Chicago"
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
