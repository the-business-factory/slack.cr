require "../../src/slack"
require "../../src/slack/testing"
require "webmock"
require "./webmock_transport"

module OfflineUsersSelectExample
  alias UI = Slack::UI

  SIGNING_SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  VERIFIER       = Slack::Webhooks::Verifier.new(SIGNING_SECRET)

  def self.receive(payload : String) : Slack::Interaction
    body = URI::Params.encode({"payload" => payload})
    request = Slack::Testing::SignedRequest.build(body, signing_secret: SIGNING_SECRET, path: "/interactions", content_type: "application/x-www-form-urlencoded")
    Slack::Interactions.parse(VERIFIER.verify(request).body)
  end

  def self.run(output : IO = STDOUT) : Nil
    install_transport
    message = UI.message(fallback_text: "Assign request 42") do |builder|
      builder.section(UI.plain("Choose an owner"), block_id: "assignment",
        accessory: UI::BlockElements::UsersSelect.new(action_id: "owner", initial_user: "U-OWNER"))
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: OfflineExample::WebMockTransport.new)
    client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: message))

    # Independently authored Slack payloads, not derived from outbound values.
    payload = %({"type":"block_actions","team":null,"trigger_id":"synthetic-trigger","actions":[{"type":"users_select","block_id":"assignment","action_id":"owner","selected_user":"U-OWNER"}]})
    case interaction = receive(payload)
    when Slack::Interactions::BlockAction
      case action = interaction.decoded_actions.first
      when Slack::Interactions::UsersSelectAction
        owner = action.selected_user || raise "Absent or null owner"
        # Real handlers must acknowledge each interaction within three seconds.
        acknowledgement = HTTP::Client::Response.new(200, body: "")
        output.puts "Assigned owner: #{owner} (acknowledged #{acknowledgement.status_code})"
        trigger = interaction.trigger_id || raise "Missing trigger"
        view = UI.form_modal(title: UI.plain("Review request 42"), submit: UI.plain("Save"),
          private_metadata: owner) do |builder|
          builder.input(label: UI.plain("Reviewers"), block_id: "review", optional: true,
            element: UI::BlockElements::MultiUsersSelect.new(action_id: "reviewers",
              initial_users: {owner}, max_selected_items: 3))
        end
        client.call(Slack::Api::ViewsOpen.new(trigger_id: trigger, view: view))
      else
        raise "Expected owner selection"
      end
    else
      raise "Expected block action"
    end

    payload = %({"type":"view_submission","team":null,"view":{"private_metadata":"U-OWNER","state":{"values":{"review":{"reviewers":{"type":"multi_users_select","selected_users":["U-ONE","W-TWO"]}}}}}})
    case interaction = receive(payload)
    when Slack::Interactions::ViewSubmission
      state = interaction.state_map.multi_users_select_value?("review", "reviewers") || raise "Missing reviewer state"
      reviewers = state.selected_users || raise "Absent or null reviewers"
      acknowledgement = HTTP::Client::Response.new(200, body: "")
      output.puts "Saved reviewers: #{reviewers.join(", ")} (acknowledged #{acknowledgement.status_code})"
    else
      raise "Expected submission"
    end
  end

  private def self.install_transport : Nil
    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing message")
      control = wire["blocks"][0]["accessory"]
      raise "Missing owner select" unless control["type"].as_s == "users_select"
      raise "Missing initial owner" unless control["initial_user"].as_s == "U-OWNER"
      HTTP::Client::Response.new(200, body: {ok: true, channel: "C-SYNTHETIC", ts: "1710000000.000001", message: {type: "message", ts: "1710000000.000001", blocks: wire["blocks"]}}.to_json)
    end
    WebMock.stub(:post, "https://slack.com/api/views.open").to_return do |request|
      wire = JSON.parse(request.body || raise "Missing form")
      input = wire["view"]["blocks"][0]
      control = input["element"]
      raise "Expected optional reviewers" unless input["optional"].as_bool && control["type"].as_s == "multi_users_select"
      raise "Missing initial reviewer" unless control["initial_users"].as_a.map(&.as_s) == ["U-OWNER"]
      raise "Missing reviewer limit" unless control["max_selected_items"].as_i == 3
      HTTP::Client::Response.new(200, body: {ok: true, view: wire["view"]}.to_json)
    end
  end
end
