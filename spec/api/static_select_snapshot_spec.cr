require "../spec_helper"
require "../support/block_kit/static_select_fixture"

alias SnapshotUI = Slack::UI

describe "Static selections at endpoint boundaries" do
  {"chat.postMessage", "views.open", "views.publish"}.each do |method|
    it "sends #{method} with an immutable nested select snapshot" do
      elements = [StaticSelectFixture.single, StaticSelectFixture.multi]
      actions = SnapshotUI::Blocks::Actions.new(elements: elements, block_id: "choices")
      blocks = [actions]
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
    end
  end
end
