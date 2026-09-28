require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineFileInputExample
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

  def self.run(output : IO = STDOUT) : Nil
    Slack.configure { |settings| settings.signing_secret = "synthetic-signing-secret" }
    install_transport

    # Independent incoming payloads. The button opens a form; only a FormModal accepts FileInput.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"button","block_id":"expense","action_id":"attach","value":"expense-42"}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      trigger = interaction.trigger_id || raise "Missing trigger"
      view = UI.form_modal(title: UI.plain("Expense"), submit: UI.plain("Send"), callback_id: "expense") do |builder|
        builder.input(label: UI.plain("Receipts"), block_id: "receipts",
          element: UI::BlockElements::FileInput.new(action_id: "files", filetypes: {"pdf", "png"}, max_files: 3))
      end
      Slack::Api::CheckedViewsOpen.new(token: "xoxb-synthetic", trigger_id: trigger,
        view: view, transport: OfflineExample::WebMockTransport.new).call
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"callback_id":"expense","state":{"values":{"receipts":{"files":{"type":"file_input","files":[{"id":"F-ONE","name":"receipt.pdf","mimetype":"application/pdf","filetype":"pdf","url_private":"https://files.slack.com/files-pri/T-SYNTHETIC-F-ONE/receipt.pdf"},{"id":"F-TWO","name":"taxi.png","mimetype":"image/png","filetype":"png"}]}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.file_input_value?("receipts", "files") || raise "Missing receipts state"
      files = state.files || raise "Absent or cleared files"
      # filetypes is only a convenience filter; the application checks each received file.
      names = files.map { |file| "#{file.id} (#{file.name || "unnamed"}, #{file.mimetype || "unknown type"})" }
      # Downloading url_private needs a token with files:read; that request is outside this example.
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Received receipts: #{names.join(", ")} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      element = wire["view"]["blocks"][0]["element"]
      raise "Expected file input" unless element["type"].as_s == "file_input"
      raise "Expected three files at most" unless element["max_files"].as_i == 3
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
