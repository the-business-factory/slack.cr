require "../spec_helper"
require "../support/api/webmock_client"
require "../support/block_kit/static_select_fixture"

alias SnapshotUI = Slack::UI

describe "Static selections at endpoint boundaries" do
  {"chat.postMessage", "views.open", "views.publish"}.each do |method|
    it "sends #{method} with an immutable nested select snapshot" do
      elements = [StaticSelectFixture.single, StaticSelectFixture.multi]
      actions = SnapshotUI::Blocks::Actions.new(elements: elements, block_id: "choices")
      blocks = [actions]
      client = ApiSupport.client("xoxb-synthetic-choices")
      request = case method
                when "chat.postMessage"
                  builder = SnapshotUI::MessageBuilder.new(fallback_text: "Choose colors.")
                  builder.add_all(blocks)
                  snapshot_request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: builder.build)
                  builder.divider
                  snapshot_request
                when "views.open"
                  builder = SnapshotUI::FormModalBuilder.new(title: SnapshotUI.plain("Colors"), submit: SnapshotUI.plain("Save"))
                  builder.add_all(blocks)
                  builder.input(label: SnapshotUI.plain("Color"), block_id: "preferences", element: StaticSelectFixture.single)
                  snapshot_request = Slack::Api::ViewsOpen.new(trigger_id: "synthetic-trigger", view: builder.build)
                  builder.divider
                  snapshot_request
                else
                  builder = SnapshotUI::HomeBuilder.new
                  builder.add_all(blocks)
                  builder.input(label: SnapshotUI.plain("Color"), block_id: "preferences", element: StaticSelectFixture.single)
                  snapshot_request = Slack::Api::ViewsPublish.new(user_id: "U-SYNTHETIC", view: builder.build)
                  builder.divider
                  snapshot_request
                end
      elements.clear
      blocks.clear
      actions.elements.each do |element|
        case element
        when SnapshotUI::BlockElements::StaticSelect
          element.options.try(&.clear)
        when SnapshotUI::BlockElements::MultiStaticSelect
          element.option_groups.try(&.each(&.options.clear))
          element.option_groups.try(&.clear)
          element.initial_options.try(&.clear)
        end
      end
      actions.elements.clear
      expected = JSON.parse(File.read("spec/fixtures/block_kit/phase_5_#{method.gsub('.', '_')}.json"))
      JSON.parse(request.to_json).should eq expected
      count = 0
      WebMock.stub(:post, "https://slack.com/api/#{method}")
        .with(headers: {"Authorization" => "Bearer xoxb-synthetic-choices"})
        .to_return do |http_request|
          count += 1
          JSON.parse(http_request.body || fail("Missing request body")).should eq expected
          response = method == "chat.postMessage" ? %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{"type":"message","ts":"1710000000.000001"}}) : %({"ok":true,"view":{"id":"V-SYNTHETIC","future":true}})
          HTTP::Client::Response.new(200, body: response)
        end
      # Client#call infers one response type, so dispatch each request type separately.
      ok = case request
           in Slack::Api::ChatPostMessage then client.call(request).ok?
           in Slack::Api::ViewsOpen       then client.call(request).ok?
           in Slack::Api::ViewsPublish    then client.call(request).ok?
           end
      ok.should be_true
      count.should eq 1
    end
  end
end
