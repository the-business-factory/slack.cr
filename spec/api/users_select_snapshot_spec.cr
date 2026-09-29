require "../spec_helper"
require "../support/one_pass"

module UsersSelectSnapshotSpec
  alias UI = Slack::UI

  it "sends owned user selections after caller, getter, and builder mutation" do
    ids = ["U-ONE", "W-TWO"]
    users = SpecSupport::OnePass.new(ids)
    multi = UI::BlockElements::MultiUsersSelect.new(action_id: "reviewers", initial_users: users,
      max_selected_items: 3, focus_on_load: false)
    single = UI::BlockElements::UsersSelect.new(action_id: "owner", initial_user: "U-OWNER")
    builder = UI::MessageBuilder.new(fallback_text: "Assign request")
    builder.section(UI.plain("Owner"), accessory: single, block_id: "assignment")
    builder.input(label: UI.plain("Reviewers"), element: multi, block_id: "review",
      optional: true, dispatch_action: false)
    request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC",
      message: builder.build, unfurl_links: false)
    ids.clear
    copy = multi
    copy.initial_users.should_not(be_nil).clear
    builder.divider
    users.passes.should eq 1
    # Independently authored from the documented user fields and request envelope.
    expected = JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Assign request","unfurl_links":false,
       "blocks":[{"type":"section","text":{"type":"plain_text","text":"Owner"},"block_id":"assignment",
         "accessory":{"type":"users_select","action_id":"owner","initial_user":"U-OWNER"}},
        {"type":"input","label":{"type":"plain_text","text":"Reviewers"},"block_id":"review","optional":true,"dispatch_action":false,
         "element":{"type":"multi_users_select","action_id":"reviewers","initial_users":["U-ONE","W-TWO"],"max_selected_items":3,"focus_on_load":false}}]}
      JSON
    JSON.parse(request.to_json).should eq expected
  end
end
