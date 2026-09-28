require "../spec_helper"

private def fixture_interaction(name : String) : Slack::Interaction
  Slack::Interaction.from_json(File.read(File.join(__DIR__, "../fixtures/interactions/#{name}.json")))
end

private def fixture_block_action(name : String) : Slack::Interactions::BlockAction
  fixture_interaction(name).should be_a(Slack::Interactions::BlockAction)
end

private def block_action_with(fields : String) : Slack::Interactions::BlockAction
  Slack::Interaction.from_json(%({"type":"block_actions"#{fields}})).should be_a(Slack::Interactions::BlockAction)
end

describe "Interaction payload context" do
  it "reads a message container click with its channel, raw message, and deprecated response_url" do
    action = fixture_block_action("block_actions_message")
    container = action.container.should be_a(Slack::Interactions::Container::Message)
    container.message_ts.should eq "1710000000.000100"
    container.channel_id.should eq "C-SYNTHETIC"
    container.is_ephemeral.should be_true
    channel = action.channel.should_not be_nil
    channel.id.should eq "C-SYNTHETIC"
    channel.name.should eq "releases"
    action.message.should_not(be_nil)["text"].as_s.should eq "Approve release?"
    action.response_url.should eq "https://hooks.slack.com/actions/A-SYNTHETIC/1/synthetic"
    action.function_data.should be_nil
    action.bot_access_token.should be_nil
    action.view_hash.should be_nil
  end

  it "reads a view container click with typed view fields and function context" do
    action = fixture_block_action("block_actions_view_function")
    action.container.should(be_a(Slack::Interactions::Container::View)).view_id.should eq "V-SYNTHETIC"
    action.channel.should be_nil
    action.view_hash.should eq "1710000000.abcd1234"

    function_data = action.function_data.should_not be_nil
    function_data.execution_id.should eq "Fx-SYNTHETIC"
    function_data.function.callback_id.should eq "approve_request"
    function_data.inputs.should eq JSON.parse(%({"requester":"U-REQUESTER","amount":42}))
    action.interactivity.should_not(be_nil)["interactivity_pointer"].as_s.should eq "1234.5678.pointer"
    action.bot_access_token.should_not(be_nil).value.should eq "xwfp-synthetic-workflow-token"

    view = action.view.should_not be_nil
    view.id.should eq "V-SYNTHETIC"
    view.team_id.should eq "T-SYNTHETIC"
    view.type.should eq "modal"
    title = view.title.should_not be_nil
    title.type.should eq "plain_text"
    title.text.should eq "Approve request"
    title.emoji.should be_true
    view.callback_id.should eq "approval"
    view.private_metadata.should eq "request-42"
    view.external_id.should eq ""
    view.view_hash.should eq "1710000000.abcd1234"
    view.root_view_id.should eq "V-ROOT"
    view.previous_view_id.should be_nil
    view.app_id.should eq "A-SYNTHETIC"
    view.bot_id.should eq "B-SYNTHETIC"
    view.clear_on_close.should be_true
    view.notify_on_close.should be_false
    view.app_installed_team_id.should eq "T-SYNTHETIC"
    view.blocks.should_not(be_nil)[0]["block_id"].as_s.should eq "decision"
  end

  it "redacts the workflow token from inspect, to_s, and re-serialized JSON" do
    action = fixture_block_action("block_actions_view_function")
    token = action.bot_access_token.should_not be_nil
    token.to_s.should_not contain("xwfp")
    action.inspect.should_not contain("xwfp-synthetic-workflow-token")
    action.to_json.should_not contain("xwfp-synthetic-workflow-token")
  end

  it "redacts interactivity from inspect and to_s but keeps raw access" do
    interactivity = %({"interactor":{"id":"U1","secret":"synthetic-interactor-secret"},"interactivity_pointer":"1.2.synthetic"})
    [fixture_interaction("block_actions_view_function"),
     Slack::Interaction.from_json(%({"type":"view_submission","interactivity":#{interactivity}})),
    ].each do |interaction|
      interaction.inspect.should_not contain("synthetic-interactor-secret")
      interaction.to_s.should_not contain("synthetic-interactor-secret")
      raw = case interaction
            when Slack::Interactions::BlockAction, Slack::Interactions::ViewSubmission then interaction.interactivity
            end
      raw.should_not(be_nil).dig("interactor", "secret").as_s.should eq "synthetic-interactor-secret"
    end
  end

  it "rejects an empty workflow token as a malformed payload" do
    expect_raises(JSON::SerializableError) { block_action_with(%(,"bot_access_token":"")) }
  end

  it "reads a message attachment container" do
    container = fixture_block_action("block_actions_attachment").container
    attachment = container.should be_a(Slack::Interactions::Container::MessageAttachment)
    attachment.message_ts.should eq "1710000000.000200"
    attachment.attachment_id.should eq 1
    attachment.channel_id.should eq "C-SYNTHETIC"
    attachment.is_ephemeral.should be_false
    attachment.is_app_unfurl.should be_true
  end

  it "keeps unknown container types and reports malformed containers at their paths" do
    unknown = block_action_with(%(,"container":{"type":"future_surface","surface_id":"S1"})).container
    unknown = unknown.should be_a(Slack::Interactions::Container::Unknown)
    unknown.type.should eq "future_surface"
    unknown.raw["surface_id"].as_s.should eq "S1"

    block_action_with("").container.should be_nil
    block_action_with(%(,"container":null)).container.should be_nil
    error = expect_raises(Slack::Interactions::TypeMismatch) { block_action_with(%(,"container":"message")).container }
    error.path.should eq "container"
    error = expect_raises(Slack::Interactions::TypeMismatch) do
      block_action_with(%(,"container":{"type":"message","channel_id":"C1"})).container
    end
    error.path.should eq "container.message_ts"
    error = expect_raises(Slack::Interactions::TypeMismatch) do
      block_action_with(%(,"container":{"type":"message_attachment","message_ts":"1.2","channel_id":"C1","attachment_id":"1"})).container
    end
    error.path.should eq "container.attachment_id"
  end

  it "reports malformed view fields when read and keeps the raw view" do
    action = block_action_with(%(,"view":{"id":7,"title":"Plain","clear_on_close":"yes"}))
    view = action.view.should_not be_nil
    expect_raises(Slack::Interactions::TypeMismatch, "view.id: expected string or null") { view.id }
    expect_raises(Slack::Interactions::TypeMismatch, "view.title: expected object") { view.title }
    expect_raises(Slack::Interactions::TypeMismatch, "view.clear_on_close: expected bool") { view.clear_on_close }
    view["title"].as_s.should eq "Plain"
  end

  it "reads view_submission response_urls, trigger_id, and view fields" do
    submission = fixture_interaction("view_submission_response_urls").should be_a(Slack::Interactions::ViewSubmission)
    submission.trigger_id.should eq "2345.6789.synthetic"
    urls = submission.response_urls
    urls.size.should eq 1
    urls.first.block_id.should eq "target"
    urls.first.action_id.should eq "channel"
    urls.first.channel_id.should eq "C-TARGET"
    urls.first.response_url.should eq "https://hooks.slack.com/app/A-SYNTHETIC/2/synthetic"
    submission.function_data.should be_nil
    submission.bot_access_token.should be_nil
    view = submission.view.should_not be_nil
    view.callback_id.should eq "share_report"
    view.private_metadata.should eq "report-7"
    view.view_hash.should eq "1710000000.efgh5678"
    submission.state_map.conversations_select_value?("target", "channel").try(&.selected_conversation).should eq "C-TARGET"
  end

  it "treats absent and null response_urls as empty" do
    [%({"type":"view_submission"}), %({"type":"view_submission","response_urls":null})].each do |json|
      Slack::Interaction.from_json(json).should(be_a(Slack::Interactions::ViewSubmission)).response_urls.should be_empty
    end
  end

  it "reads view_closed is_cleared" do
    closed = fixture_interaction("view_closed_cleared").should be_a(Slack::Interactions::ViewClosed)
    closed.is_cleared.should be_true
    closed.view.should_not(be_nil).title.should_not(be_nil).text.should eq "Share report"
    Slack::Interaction.from_json(%({"type":"view_closed"})).should(be_a(Slack::Interactions::ViewClosed)).is_cleared.should be_nil
  end

  it "reads message shortcut channel, message_ts, and raw message" do
    shortcut = fixture_interaction("message_action").should be_a(Slack::Interactions::MessageAction)
    shortcut.channel.should_not(be_nil).name.should eq "support"
    shortcut.message_ts.should eq "1710000000.000300"
    shortcut.message.should_not(be_nil)["text"].as_s.should eq "The export fails"
  end

  it "reads an optional channel on a shortcut" do
    shortcut = Slack::Interaction.from_json(%({"type":"shortcut","callback_id":"open","channel":{"id":"C1","name":"general"}}))
    shortcut.should(be_a(Slack::Interactions::Shortcut)).channel.should_not(be_nil).id.should eq "C1"
    Slack::Interaction.from_json(%({"type":"shortcut"})).should(be_a(Slack::Interactions::Shortcut)).channel.should be_nil
  end
end
