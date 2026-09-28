require "./spec_helper"
require "../examples/support/message_example"
require "../examples/support/modal_example"
require "../examples/support/home_example"
require "../examples/support/static_select_example"
require "../examples/support/overflow_example"
require "../examples/support/checkboxes_example"
require "../examples/support/radio_buttons_example"
require "../examples/support/message_update_example"
require "../examples/support/view_update_example"
require "../examples/support/users_select_example"
require "../examples/support/view_push_example"
require "../examples/support/modal_errors_example"
require "../examples/support/modal_clear_example"
require "../examples/support/channels_select_example"
require "../examples/support/modal_push_example"

require "../examples/support/modal_update_example"
require "../examples/support/conversations_select_example"

require "../examples/support/date_time_pickers_example"
require "../examples/support/datetime_picker_example"
require "../examples/support/video_example"
require "../examples/support/external_select_example"
require "../examples/support/remote_file_example"

require "../examples/support/rich_text_example"
require "../examples/support/number_input_example"
require "../examples/support/file_input_example"
require "../examples/support/url_input_example"
require "../examples/support/email_input_example"
require "../examples/support/table_example"
require "../examples/support/data_table_example"
require "../examples/support/data_visualization_example"
require "../examples/support/card_carousel_example"
require "../examples/support/container_example"
require "../examples/support/rich_text_input_example"
require "../examples/support/markdown_example"
require "../examples/support/workflow_button_example"
require "../examples/support/context_actions_example"
require "../examples/support/event_delivery_example"
require "../examples/support/event_catalog_example"
require "../examples/support/interaction_context_example"
require "../examples/support/alert_example"
require "../examples/support/socket_mode_example"
require "../examples/support/slash_command_example"
require "../examples/support/received_blocks_example"
require "../examples/support/web_api_example"
require "../examples/support/retry_policy_example"
require "../examples/support/workflow_step_example"
require "../examples/support/file_upload_example"
require "../examples/support/thread_history_example"
require "../examples/support/streaming_example"
require "../examples/support/plan_example"
require "../examples/support/attachments_example"
require "../examples/support/ephemeral_reply_example"
require "../examples/support/socket_mode_client_example"
require "../examples/support/assistant_thread_example"
require "../examples/support/user_group_example"
require "../examples/support/incident_channel_example"
require "../examples/support/testing_example"
require "../examples/support/app_example"
require "../examples/support/assistant_events_example"
require "../examples/support/incident_triage_example"
require "../examples/support/app_manifest_example"
require "../examples/support/custom_step_example"
require "../examples/support/socket_mode_app_example"
require "../examples/support/assistant_example"

describe "documented Block Kit workflows" do
  around_each do |example|
    allow_net_connect = WebMock.allows_net_connect?
    begin
      example.run
    ensure
      WebMock.reset
      WebMock.allow_net_connect = allow_net_connect
    end
  end

  it "renders the message components" do
    output = IO::Memory.new
    OfflineMessageExample.run(output)
    message = JSON.parse(output.to_s)
    message["text"].should eq("Morgan's request 42 needs approval.")
    blocks = message["blocks"].as_a
    blocks.map(&.["type"].as_s).should eq(["section", "divider", "actions"])
    blocks[0]["text"]["text"].should eq("*Request 42* from Morgan")
    blocks[2]["elements"][0]["value"].should eq("42")
  end

  it "uploads an in-memory file and shares it to a channel" do
    output = IO::Memory.new
    OfflineFileUploadExample.run(output)
    output.to_s.should eq "Uploaded F123 (Release notes) to C123\n"
  end

  it "tests a slash command handler with a signed request and a recording transport" do
    output = IO::Memory.new
    transport = OfflineTestingExample.run(output)

    output.to_s.lines.should eq ["/api/chat.postMessage " + %({"channel":"C-TEAM","text":"<@U-SYNTHETIC> starts the standup: blockers first"}),
                                 "Rejected a forged request; Slack calls: 1"]
    posted = transport.requests.first
    posted.headers["Authorization"].should eq "Bearer xoxb-synthetic-testing"
    JSON.parse(posted.body.to_s).should eq JSON.parse(%({"channel":"C-TEAM","text":"<@U-SYNTHETIC> starts the standup: blockers first"}))
  end

  it "calls typed and generic Web API methods and reads a Slack error code" do
    output = IO::Memory.new
    OfflineWebApiExample.run(output)
    output.to_s.should eq("Added :eyes: to C123\nCustom emoji: shipit\nDelete failed: message_not_found\n")
  end

  it "waits Retry-After after HTTP 429 and posts again, then stops at a wait above max_wait" do
    output = IO::Memory.new
    waits = [] of Time::Span
    OfflineRetryPolicyExample.run(output, ->(span : Time::Span) { waits << span; nil })
    output.to_s.lines.should eq ["Posted 1710000000.000200 to C123", "Rate limited; try again in 120 seconds"]
    waits.should eq [2.seconds]
  end

  it "completes a workflow step with outputs and fails one without its input" do
    output = IO::Memory.new
    sent = OfflineWorkflowStepExample.run(output)
    output.to_s.lines.should eq ["Completed assign_reviewer Fx-STEP-1: U-REVIEWER",
                                 "Failed assign_reviewer Fx-STEP-2: no reviewer"]
    sent.should eq [
      JSON.parse(%({"function_execution_id":"Fx-STEP-1","outputs":{"reviewer_id":"U-REVIEWER"}})),
      JSON.parse(%({"function_execution_id":"Fx-STEP-2","error":"Choose a reviewer."})),
    ]
  end

  it "reads channel history and a thread across cursor pages" do
    output = IO::Memory.new
    OfflineThreadHistoryExample.run(output)
    output.to_s.should eq(<<-TEXT)
      1710000300.000100 Deploy finished
      1710000200.000100 Deploy started
      1710000100.000100 Morning
        U2: Deploy started
        U1: Watching the logs
        U3: All green

      TEXT
  end

  it "prepares an app thread with prompts, a title, and a status" do
    output = IO::Memory.new
    OfflineAssistantThreadExample.run(output)
    output.to_s.should eq("Suggested 2 prompts\nTitled the thread\nShowing a status\nCleared the status\n")
  end

  it "reads members across cursor pages and fills an on-call user group" do
    output = IO::Memory.new
    sent = OfflineUserGroupExample.run(output)
    output.to_s.should eq(<<-TEXT)
      People: ana, cy
      Lead: Ana Ruiz (Europe/Madrid)
      @oncall: 2 members

      TEXT
    sent.should eq [
      URI::Params.parse("name=On-call&description=Led+by+Ana+Ruiz&handle=oncall"),
      URI::Params.parse("usergroup=S1&users=U1%2CU3&include_count=true"),
    ]
  end

  it "acknowledges, pins, and bookmarks an incident, then reads its reactions and pins" do
    output = IO::Memory.new
    sent = OfflineIncidentTriageExample.run(output)
    output.to_s.should eq(<<-TEXT)
      Already watching
      Bookmarked Queue runbook (Bk01)
      Reactions: eyes x1, rotating_light x2
      Pinned: Queue is stuck

      TEXT
    sent.should eq [
      URI::Params.parse("channel=C123&timestamp=1710000000.000100"),
      URI::Params.parse("channel_id=C123&title=Queue+runbook&type=link&link=https%3A%2F%2Frunbooks.example.test%2Fqueue&emoji=%3Abooks%3A"),
    ]
  end

  it "fixes a reported manifest problem, creates the app, and exports its manifest" do
    output = IO::Memory.new
    sent = OfflineAppManifestExample.run(output)

    output.to_s.should eq(<<-TEXT)
      /settings/event_subscriptions: Event Subscription requires either Request URL or Socket Mode Enabled
      Manifest is valid
      Created A0DEPLOY01 with client ID 1234.5678
      Signing secret: [REDACTED]
      Exported Deploy Bot

      TEXT
    sent.map(&.[0]).should eq %w[apps.manifest.validate apps.manifest.validate apps.manifest.create apps.manifest.export]
    JSON.parse(sent[0][1]["manifest"])["settings"].should eq JSON.parse(%({"event_subscriptions":{"bot_events":["app_mention"]}}))
    JSON.parse(sent[2][1]["manifest"])["settings"].should eq JSON.parse(
      %({"socket_mode_enabled":true,"event_subscriptions":{"bot_events":["app_mention"]}}))
    JSON.parse(sent[2][1]["manifest"])["oauth_config"].should eq JSON.parse(
      %({"scopes":{"bot":["app_mentions:read","chat:write"]}}))
    sent[3][1].should eq URI::Params.parse("app_id=A0DEPLOY01")
  end

  it "sets up and archives an incident channel after a taken name" do
    output = IO::Memory.new
    transport = OfflineIncidentChannelExample.run(output)
    output.to_s.lines.should eq ["incident-42 is taken; created incident-42-1 (C42)",
                                 "Invited 3 responders",
                                 "Topic: Checkout errors. Updates every 30 min.",
                                 "Lead DM: D-LEAD",
                                 "Archived C42"]
    transport.requests.map { |request| {request.uri.path, JSON.parse(request.body.to_s)} }.should eq [
      {"/api/conversations.create", JSON.parse(%({"name":"incident-42"}))},
      {"/api/conversations.create", JSON.parse(%({"name":"incident-42-1"}))},
      {"/api/conversations.invite", JSON.parse(%({"channel":"C42","users":"U-LEAD,U-ONCALL,U-GONE","force":true}))},
      {"/api/conversations.setTopic", JSON.parse(%({"channel":"C42","topic":"Checkout errors. Updates every 30 min."}))},
      {"/api/conversations.open", JSON.parse(%({"users":"U-LEAD"}))},
      {"/api/conversations.archive", JSON.parse(%({"channel":"C42"}))},
    ]
  end

  it "streams a threaded answer with a plan and final feedback blocks" do
    output = IO::Memory.new
    OfflineStreamingExample.run(output)
    output.to_s.should eq("Started stream 1721609600.123456 in C123\nAppended the plan\nFinal text: Checking the report. Revenue grew 4%.\n")
  end

  it "streams task updates in plan mode and stops with a final plan block" do
    output = IO::Memory.new
    OfflinePlanExample.run(output)
    output.to_s.should eq("Started plan 1721609700.000200\nUpdated 2 tasks\nFinal text: The deploy is healthy.\n")
  end

  it "posts a message with a colored attachment, metadata, and an emoji icon" do
    output = IO::Memory.new
    OfflineAttachmentsExample.run(output)
    body, summary = output.to_s.lines
    JSON.parse(body).should eq JSON.parse(<<-JSON)
      {"channel":"C123","text":"Deploy 812 finished",
       "blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*Deploy 812* finished"}}],
       "attachments":[{"color":"#2EB886","blocks":[{"type":"context","elements":[{"type":"mrkdwn","text":"api: healthy · web: healthy"}]}]}],
       "metadata":{"event_type":"deploy_finished","event_payload":{"deploy_id":"812"}},
       "icon_emoji":":rocket:"}
      JSON
    summary.should eq "Posted 1710000123.000200 with metadata deploy_finished"
  end

  it "links a saved message in an ephemeral thread reply and schedules a reminder" do
    output = IO::Memory.new
    OfflineEphemeralReplyExample.run(output)
    ephemeral, scheduled, summary = output.to_s.lines
    JSON.parse(ephemeral).should eq JSON.parse(<<-JSON)
      {"channel":"C123","user":"U123","text":"Saved for later",
       "blocks":[{"type":"section","text":{"type":"mrkdwn",
         "text":"Saved <https://example.slack.com/archives/C123/p1710000000000100|this message>. I will remind you tomorrow."}}],
       "thread_ts":"1710000000.000100"}
      JSON
    JSON.parse(scheduled).should eq JSON.parse(<<-JSON)
      {"channel":"D123","post_at":1710086400,
       "text":"Reminder: <https://example.slack.com/archives/C123/p1710000000000100|saved message>"}
      JSON
    summary.should eq "Ephemeral 1710000050.000200; reminder Q0REMIND1 at 1710086400"
  end

  it "posts a button, opens a modal, and reads its signed submission" do
    output = IO::Memory.new
    OfflineModalExample.run(output)
    output.to_s.should eq("Saved request 42: Need a test environment. (acknowledged 200)\n")
  end

  it "publishes Home and reads the dispatched note" do
    output = IO::Memory.new
    OfflineHomeExample.run(output)
    output.to_s.should eq("Published Home V123 offline.\nReceived Home note: Ready to review\n")
  end

  it "posts a static select and reads the signed multi-select submission" do
    output = IO::Memory.new
    OfflineStaticSelectExample.run(output)
    output.to_s.should eq("Saved notification colors: red, blue (acknowledged 200)\n")
  end
  it "posts an overflow menu and acknowledges a signed URL selection" do
    output = IO::Memory.new
    OfflineOverflowExample.run(output)
    output.to_s.should eq "Selected request action: details (acknowledged 200)\n"
  end
  it "posts checkboxes and acknowledges checked and cleared signed selections" do
    output = IO::Memory.new
    OfflineCheckboxesExample.run(output)
    output.to_s.should eq "Selected notifications: digest (acknowledged 200)\nSaved notifications: none (acknowledged 200)\n"
  end
  it "posts radio buttons and reads signed selection and unselected submission state" do
    output = IO::Memory.new
    OfflineRadioButtonsExample.run(output)
    output.to_s.should eq "Selected delivery: digest (acknowledged 200)\nSaved delivery: none (acknowledged 200)\n"
  end

  it "replaces a posted approval prompt with its completed status" do
    output = IO::Memory.new
    OfflineMessageUpdateExample.run(output)
    output.to_s.should eq("Updated C123/1710000000.000001: Request 42 approved.\n")
  end
  it "adds and shares a remote file, then builds its block for an unfurl request" do
    output = IO::Memory.new
    OfflineRemoteFileExample.run(output)
    added, shared, unfurls = output.to_s.lines
    added.should eq "Added remote file F08EAQ813FW"
    shared.should eq "Shared plan-2026-q4 to C123"
    JSON.parse(unfurls).should eq JSON.parse(<<-JSON)
      {"https://docs.example.test/plans/2026-q4":{"blocks":[
        {"type":"file","external_id":"plan-2026-q4","source":"remote","block_id":"plan.file"}]}}
      JSON
  end
  it "updates an opened form using its returned ID and hash with stable input IDs" do
    output = IO::Memory.new
    OfflineViewUpdateExample.run(output)
    output.to_s.should eq("Updated modal V123 with stable reason/text input IDs (hash next-hash).\n")
  end
  it "assigns an owner and submits reviewers through signed user selections" do
    output = IO::Memory.new
    OfflineUsersSelectExample.run(output)
    output.to_s.should eq "Assigned owner: U-OWNER (acknowledged 200)\nSaved reviewers: U-ONE, W-TWO (acknowledged 200)\n"
  end
  it "pushes the next screen using a fresh interaction from an existing modal" do
    output = IO::Memory.new
    OfflineViewPushExample.run(output)
    output.to_s.should eq("Pushed details V2 onto modal V1 (acknowledged 200).\n")
  end
  it "returns field errors for a signed submission and accepts corrected input" do
    output = IO::Memory.new
    rejected, accepted = OfflineModalErrorsExample.run(output)
    rejected.status_code.should eq(200)
    rejected.headers["Content-Type"].should eq("application/json")
    rejected.body.should eq(%q({"response_action":"errors","errors":{"request.reason":"Explain why you need this request (at least 10 characters)."}}))
    accepted.status_code.should eq(200)
    accepted.body.should eq("")
    output.to_s.should eq("Rejected short reason; accepted corrected reason (HTTP 200).\n")
  end
  it "chooses a notification channel and submits destination channels" do
    output = IO::Memory.new
    OfflineChannelsSelectExample.run(output)
    output.to_s.should eq "Selected notification channel: C-NOTIFY (acknowledged 200)\nSaved destinations: C-ONE, C-TWO (acknowledged 200)\n"
  end
  it "prepares a clear acknowledgment for a signed successful submission" do
    output = IO::Memory.new
    response = OfflineModalClearExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    response.body.should eq(%q({"response_action":"clear"}))
    output.to_s.should eq("Accepted reason: Need a test environment. (prepared HTTP 200 clear)\n")
  end

  it "returns the next form in a signed submission acknowledgment" do
    output = IO::Memory.new
    response = OfflineModalPushExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    expected = JSON.parse(<<-JSON)
      {"response_action":"push","view":{"type":"modal","title":{"type":"plain_text","text":"Delivery details"},
        "submit":{"type":"plain_text","text":"Save"},"close":{"type":"plain_text","text":"Back"},
        "callback_id":"request.delivery","private_metadata":"42","blocks":[
          {"type":"section","text":{"type":"plain_text","text":"Reason: Need a test environment."}},
          {"type":"input","block_id":"delivery","label":{"type":"plain_text","text":"Delivery note"},
            "element":{"type":"plain_text_input","action_id":"note","multiline":true}}]}}
      JSON
    JSON.parse(response.body).should eq(expected)
    output.to_s.should eq("Prepared delivery form from signed submission (HTTP 200).\n")
  end

  it "acknowledges a signed submission with an updated form and retained input IDs" do
    output = IO::Memory.new
    response = OfflineModalUpdateExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    # Complete acknowledgment expected independently of the example's builder.
    JSON.parse(response.body).should eq(JSON.parse(<<-JSON))
      {"response_action":"update","view":{"type":"modal",
        "title":{"type":"plain_text","text":"Review request"},"submit":{"type":"plain_text","text":"Save"},
        "callback_id":"request.review","private_metadata":"42","blocks":[
          {"type":"section","text":{"type":"plain_text","text":"Choose an owner for: Need a test environment."}},
          {"type":"input","block_id":"request.reason","label":{"type":"plain_text","text":"Reason"},
            "element":{"type":"plain_text_input","action_id":"reason","multiline":true}},
          {"type":"input","block_id":"request.owner","label":{"type":"plain_text","text":"Owner"},
            "element":{"type":"users_select","action_id":"owner"}}]}}
      JSON
    output.to_s.should eq("Prepared updated form with retained request.reason/reason IDs (HTTP 200).\n")
  end
  it "acknowledges a long submitted reason with a bounded display preview" do
    payload = %({"type":"view_submission","view":{"type":"modal","callback_id":"request.reason","private_metadata":"42","state":{"values":{"request.reason":{"reason":{"type":"plain_text_input","value":"#{"界" * 3000}"}}}}}})
    body = URI::Params.encode({"payload" => payload})
    timestamp = Time.utc.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => "application/x-www-form-urlencoded",
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => Slack::Webhooks::Signature.new(Slack::Auth::Secret.new("synthetic-signing-secret"), timestamp, body).compute,
    }
    response = OfflineModalUpdateExample.handle(HTTP::Request.new("POST", "/interactions", headers, body))
    response.status_code.should eq(200)
    wire = JSON.parse(response.body)
    wire["response_action"].as_s.should eq("update")
    wire["view"]["blocks"][0]["text"]["text"].as_s.should eq("Choose an owner for: #{"界" * 200}…")
  end

  it "chooses a filtered conversation and submits conversation destinations" do
    output = IO::Memory.new
    OfflineConversationsSelectExample.run(output)
    output.to_s.should eq "Selected notification conversation: D-NOTIFY (acknowledged 200)\nSaved destinations: C-ONE, G-TWO (acknowledged 200)\n"
  end

  it "collects a date and time choice through a signed scheduling form" do
    output = IO::Memory.new
    OfflineDateTimePickersExample.run(output)
    output.to_s.should eq "Chosen date: 2028-02-29 (acknowledged 200)\nSaved choice: 2028-03-01 at 09:30 (America/Chicago; acknowledged 200)\n"
  end

  it "proposes and saves a meeting start through a signed datetime form" do
    output = IO::Memory.new
    OfflineDatetimePickerExample.run(output)
    output.to_s.should eq "Proposed start: 2028-02-29T16:30:00Z (acknowledged 200)\nSaved start: 2028-02-29T17:30:00Z (acknowledged 200)\n"
  end

  it "posts an embedded video and rejects a non-HTTPS video link locally" do
    output = IO::Memory.new
    OfflineVideoExample.run(output)
    output.to_s.should eq "Posted video message C123/1710000000.000100\nRejected before sending: video.video_url.not_https\n"
  end

  it "suggests projects for a signed query and reads the signed selections" do
    output = IO::Memory.new
    response = OfflineExternalSelectExample.run(output)
    response.status_code.should eq(200)
    response.headers["Content-Type"].should eq("application/json")
    JSON.parse(response.body).should eq(JSON.parse(<<-JSON))
      {"options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"},
        {"text":{"type":"plain_text","text":"Artemis"},"value":"artemis"}]}
      JSON
    output.to_s.should eq "Suggested 2 projects (HTTP 200)\nSelected project: artemis (acknowledged 200)\nSaved related projects: artemis, gemini (acknowledged 200)\n"
  end

  it "posts rich text notes and reads a signed rich text reply" do
    output = IO::Memory.new
    posted = OfflineRichTextExample.run(output)
    output.to_s.should eq "Mentioned users: U-AUTHOR\nFollow-up items: docs, changelog\nWorkflows offered: Send feedback (Ft-FEEDBACK)\n"
    # Authored from Slack's rich text element references and chat.postMessage, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Release 2.0 is live","blocks":[
        {"type":"rich_text","block_id":"notes","elements":[
          {"type":"rich_text_section","elements":[
            {"type":"text","text":"Release "},{"type":"text","text":"2.0","style":{"bold":true,"highlight":true}},
            {"type":"text","text":" is live for "},{"type":"team","team_id":"T-PARTNER"},{"type":"text","text":". "},
            {"type":"emoji","name":"tada"}]},
          {"type":"rich_text_list","style":"bullet","elements":[
            {"type":"rich_text_section","elements":[{"type":"text","text":"Faster builds"}]},
            {"type":"rich_text_section","elements":[{"type":"text","text":"New "},{"type":"link","url":"https://example.com/api","text":"API"}]},
            {"type":"rich_text_section","elements":[{"type":"text","text":"Rollout: "},
              {"type":"canvas","file_id":"F-RUNBOOK","section_id":"temp:C:rollout","text":"Release runbook","style":{"underline":true}}]}]},
          {"type":"rich_text_preformatted","language":"shell","elements":[{"type":"text","text":"shards update"}]}]}]}
      JSON
  end

  it "posts an LLM markdown answer and rejects oversized markdown locally" do
    output = IO::Memory.new
    posted = OfflineMarkdownExample.run(output)
    output.to_s.should eq "Posted answer to C-SYNTHETIC/1710000000.000400\nRejected before sending: message.markdown.too_long\n"
    # Authored from Slack's markdown block and chat.postMessage references, not from the serializer.
    posted.should eq JSON.parse(<<-'JSON')
      {"channel":"C-SYNTHETIC","text":"How to rotate the signing secret","blocks":[
        {"type":"markdown","text":"## Rotate the signing secret\n\n1. Open **Basic Information**.\n2. Select _Regenerate_ next to the secret.\n3. Update `SLACK_SIGNING_SECRET` and redeploy.\n\nSee [Verifying requests](https://docs.slack.dev/authentication/verifying-requests-from-slack)."},
        {"type":"context","elements":[{"type":"plain_text","text":"Generated answer. Check the steps before you use them."}]}]}
      JSON
  end

  it "opens a deploy status modal with an alert for each check" do
    output = IO::Memory.new
    opened = OfflineAlertExample.run(output)
    output.to_s.should eq "Opened deploy status with 2 alerts\nRejected before sending: alert.text.too_long\n"
    # Authored from Slack's alert block and views.open references, not from the serializer.
    opened.should eq JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal",
        "title":{"type":"plain_text","text":"Deploy 42"},"close":{"type":"plain_text","text":"Done"},
        "blocks":[
          {"type":"alert","block_id":"check.build","text":{"type":"mrkdwn","text":"*Build* passed"},"level":"success"},
          {"type":"alert","block_id":"check.migrations","text":{"type":"mrkdwn","text":"*Migrations* failed"},"level":"error"},
          {"type":"section","text":{"type":"plain_text","text":"Fix the failed checks, then deploy again."}}]}}
      JSON
  end

  it "posts a revenue table built from application records" do
    output = IO::Memory.new
    posted = OfflineTableExample.run(output)
    output.to_s.should eq "Posted 2 regions to C-SYNTHETIC/1710000000.000300\nRejected before sending: table.row.too_many_cells\n"
    # Authored from Slack's table block and chat.postMessage references, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Q3 revenue by region","blocks":[
        {"type":"table","block_id":"q3.revenue",
         "column_settings":[{"is_wrapped":true},null,{"align":"right"},{"align":"right"}],
         "rows":[
           [{"type":"raw_text","text":"Region"},{"type":"raw_text","text":"Owner"},
            {"type":"raw_text","text":"Deals"},{"type":"raw_text","text":"Revenue"}],
           [{"type":"raw_text","text":"EMEA"},
            {"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user","user_id":"U-EMEA"}]}]},
            {"type":"raw_number","value":12,"text":"12"},{"type":"raw_number","value":1250000.0,"text":"$1250000.00"}],
           [{"type":"raw_text","text":"APAC"},
            {"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user","user_id":"U-APAC"}]}]},
            {"type":"raw_number","value":7,"text":"7"},{"type":"raw_number","value":980000.5,"text":"$980000.50"}]]}]}
      JSON
  end

  it "posts answer feedback and delete buttons and reads signed feedback and delete clicks" do
    output = IO::Memory.new
    posted = OfflineContextActionsExample.run(output)
    output.to_s.lines.should eq ["Feedback: bad", "Delete requested: answer.delete"]
    # Authored from Slack's context actions, feedback buttons, and icon button references, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Answer","blocks":[
        {"type":"section","block_id":"answer","text":{"type":"plain_text","text":"Rotate the signing secret in the app settings."}},
        {"type":"context_actions","block_id":"answer.actions","elements":[
          {"type":"feedback_buttons","action_id":"answer.feedback",
           "positive_button":{"text":{"type":"plain_text","text":"Good"},"value":"good","accessibility_label":"Mark this answer as good"},
           "negative_button":{"text":{"type":"plain_text","text":"Bad"},"value":"bad","accessibility_label":"Mark this answer as bad"}},
          {"type":"icon_button","icon":"trash","text":{"type":"plain_text","text":"Delete"},"action_id":"answer.delete","value":"delete",
           "confirm":{"title":{"type":"plain_text","text":"Delete answer?"},"text":{"type":"plain_text","text":"The answer is removed."},
                      "confirm":{"type":"plain_text","text":"Delete"},"deny":{"type":"plain_text","text":"Keep"},"style":"danger"},
           "visible_to_user_ids":["U-ASKER"]}]}]}
      JSON
  end

  it "posts a paged data table of support tickets" do
    output = IO::Memory.new
    posted = OfflineDataTableExample.run(output)
    output.to_s.should eq "Posted 3 tickets to C-SYNTHETIC/1710000000.000400\nRejected before sending: data_table.row.width_mismatch\n"
    # Authored from Slack's data table block and chat.postMessage references, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Open support tickets","blocks":[
        {"type":"data_table","block_id":"support.open","caption":"Open support tickets","page_size":2,
         "rows":[
           [{"type":"raw_text","text":"Ticket"},{"type":"raw_text","text":"Assignee"},{"type":"raw_text","text":"Age (days)"}],
           [{"type":"raw_text","text":"SUP-101"},
            {"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user","user_id":"U-ALEX"}]}]},
            {"type":"raw_number","value":3,"text":"3"}],
           [{"type":"raw_text","text":"SUP-102"},
            {"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user","user_id":"U-SAM"}]}]},
            {"type":"raw_number","value":12,"text":"12"}],
           [{"type":"raw_text","text":"SUP-103"},
            {"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"user","user_id":"U-ALEX"}]}]},
            {"type":"raw_number","value":1,"text":"1"}]]}]}
      JSON
  end

  it "posts deploy and latency charts built from application records" do
    output = IO::Memory.new
    posted = OfflineDataVisualizationExample.run(output)
    output.to_s.should eq "Posted 3 services and 6 latency points to C-SYNTHETIC/1710000000.000400\n" \
                          "Rejected before sending: line.series.data.missing_category\n"
    # Authored from Slack's data visualization block and chat.postMessage references, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Weekly deploy report","blocks":[
        {"type":"data_visualization","block_id":"deploys","title":"Deploys by service",
         "chart":{"type":"pie","segments":[
           {"label":"api","value":14},{"label":"web","value":9},{"label":"worker","value":3}]}},
        {"type":"data_visualization","title":"p95 latency",
         "chart":{"type":"line",
           "series":[
             {"name":"us-east","data":[{"label":"Mon","value":120.5},{"label":"Tue","value":98.0},{"label":"Wed","value":101.25}]},
             {"name":"eu-west","data":[{"label":"Mon","value":140.0},{"label":"Tue","value":133.5},{"label":"Wed","value":150.0}]}],
           "axis_config":{"categories":["Mon","Tue","Wed"],"x_label":"Day","y_label":"Latency (ms)"}}}]}
      JSON
  end

  it "posts a carousel of department cards and reads a signed card button click" do
    output = IO::Memory.new
    posted = OfflineCardCarouselExample.run(output)
    output.to_s.should eq "Posted 2 cards to C-SYNTHETIC/1710000000.000400\nVisit requested: wellness\nRejected before sending: card.content.missing\n"
    # Authored from Slack's card, carousel, and Slack icon references, not from the serializer.
    posted.should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Departments open for visits","blocks":[
        {"type":"carousel","block_id":"departments","elements":[
          {"type":"card","block_id":"department.mdr","slack_icon":{"type":"icon","name":"code"},
           "title":{"type":"plain_text","text":"MDR"},"body":{"type":"plain_text","text":"Refining data files."},
           "actions":[{"type":"button","text":{"type":"plain_text","text":"Visit"},"action_id":"visit.request","value":"mdr","style":"primary"}]},
          {"type":"card","block_id":"department.wellness","slack_icon":{"type":"icon","name":"heart"},
           "title":{"type":"plain_text","text":"Wellness Center"},"body":{"type":"plain_text","text":"Please wait until called."},
           "actions":[{"type":"button","text":{"type":"plain_text","text":"Visit"},"action_id":"visit.request","value":"wellness","style":"primary"}]}]}]}
      JSON
  end

  it "posts a collapsible bulk update and reads a signed click inside the container" do
    output = IO::Memory.new
    posted = OfflineContainerExample.run(output)
    output.to_s.should eq "bulk.confirm in bulk.actions: DCW-1024,DCW-1025\n"
    # Authored from Slack's container block and chat.postMessage references, not from the serializer.
    posted.should eq JSON.parse(<<-'JSON')
      {"channel":"C-SYNTHETIC","text":"Bulk update: 2 records selected","blocks":[
        {"type":"container","block_id":"bulk.update","is_collapsible":true,
         "title":{"type":"plain_text","text":"Bulk update: 2 records selected"},
         "subtitle":{"type":"plain_text","text":"Review changes before confirming"},
         "child_blocks":[
           {"type":"section","block_id":"record.DCW-1024","text":{"type":"mrkdwn","text":"*DCW-1024*\nStatus: Open → Closed"}},
           {"type":"divider"},
           {"type":"section","block_id":"record.DCW-1025","text":{"type":"mrkdwn","text":"*DCW-1025*\nStatus: In Progress → Closed"}},
           {"type":"actions","block_id":"bulk.actions","elements":[
             {"type":"button","text":{"type":"plain_text","text":"Confirm all"},"action_id":"bulk.confirm","value":"DCW-1024,DCW-1025","style":"primary"},
             {"type":"button","text":{"type":"plain_text","text":"Cancel"},"action_id":"bulk.cancel"}]}]}]}
      JSON
  end

  it "collects whole seats and a decimal budget through a signed modal form" do
    output = IO::Memory.new
    rejected, accepted = OfflineNumberInputExample.run(output)
    output.to_s.lines.should eq ["Seats entered: 14 (acknowledged 200)", "Rejected seats: 14", "Booked 4 seats with 12.50 budget"]
    rejected.status_code.should eq 200
    rejected.headers["Content-Type"].should eq "application/json"
    JSON.parse(rejected.body).should eq JSON.parse(%({"response_action":"errors","errors":{"booking.seats":"Enter from 1 to 12 seats."}}))
    # Slack closes the submitted view only for an empty HTTP 200 acknowledgment.
    accepted.status_code.should eq 200
    accepted.body.should be_empty
  end

  it "collects uploaded receipts through a signed form submission" do
    output = IO::Memory.new
    OfflineFileInputExample.run(output)
    output.to_s.should eq "Received receipts: F-ONE (receipt.pdf, application/pdf), F-TWO (taxi.png, image/png) (acknowledged 200)\n"
  end

  it "collects an HTTPS page link through a signed modal form" do
    output = IO::Memory.new
    request, acknowledgements = OfflineUrlInputExample.run(output)
    # Authored from Slack's URL input, Input block, and views.open contracts.
    request.should eq JSON.parse(<<-JSON)
      {"trigger_id":"synthetic-trigger","view":{"type":"modal","title":{"type":"plain_text","text":"Report a bug"},
       "submit":{"type":"plain_text","text":"Send"},"callback_id":"bug_report","blocks":[
        {"type":"input","label":{"type":"plain_text","text":"Summary"},"block_id":"bug.summary",
         "element":{"type":"plain_text_input","action_id":"summary"}},
        {"type":"input","label":{"type":"plain_text","text":"Page link"},"block_id":"bug.link","dispatch_action":true,
         "element":{"type":"url_text_input","action_id":"page","dispatch_action_config":{"trigger_actions_on":["on_enter_pressed"]},
          "focus_on_load":true,"placeholder":{"type":"plain_text","text":"https://"}}}]}}
      JSON
    output.to_s.lines.should eq ["Link entered: http://intranet.example/wiki (acknowledged 200)",
                                 "Rejected link: http://intranet.example/wiki",
                                 %(Reported "Login fails" at status.example.com)]
    rejected, accepted = acknowledgements
    rejected.headers["Content-Type"].should eq "application/json"
    JSON.parse(rejected.body).should eq JSON.parse(%({"response_action":"errors","errors":{"bug.link":"Enter an HTTPS link."}}))
    accepted.status_code.should eq 200
    accepted.body.should be_empty
  end

  it "invites a guest by email through a signed modal form" do
    output = IO::Memory.new
    rejected, accepted = OfflineEmailInputExample.run(output)
    output.to_s.lines.should eq ["Email entered: lead@partner.example (acknowledged 200)", "Rejected email: lead@other.example", "Invited lead@partner.example"]
    rejected.status_code.should eq 200
    rejected.headers["Content-Type"].should eq "application/json"
    JSON.parse(rejected.body).should eq JSON.parse(%({"response_action":"errors","errors":{"invite.email":"Enter a partner.example address."}}))
    accepted.status_code.should eq 200
    accepted.body.should be_empty
  end

  it "reads a formatted standup from a signed Home rich text input action" do
    output = IO::Memory.new
    OfflineRichTextInputExample.run(output)
    output.to_s.lines.should eq [
      "Standup text: Yesterday: paired with @U-PAIR / - Ship the release",
      "Mentioned: U-PAIR",
      "Skipped malformed standup at actions[0].rich_text_value.elements[0].type",
    ]
  end

  it "posts message workflow buttons with trigger inputs and rejects them on Home" do
    output = IO::Memory.new
    posted = OfflineWorkflowButtonExample.run(output)
    output.to_s.lines.should eq ["Posted workflow buttons for INC-7 to C-SYNTHETIC/1710000000.000400",
                                 "Rejected Home tab: home.workflow_button.unsupported_surface"]
    posted.should eq JSON.parse(File.read("spec/fixtures/block_kit/workflow_button_chat_postMessage.json"))
  end

  it "acknowledges a signed retry of an event type the library does not map" do
    output = IO::Memory.new
    response = OfflineEventDeliveryExample.run(output)
    response.status_code.should eq(200)
    response.body.should be_empty
    output.to_s.should eq("Skipped synthetic_future_event Ev-SYNTHETIC (retry 1: http_timeout)\n")
  end

  it "routes signed app events, message subtypes, and a rate-limit notice" do
    output = IO::Memory.new
    OfflineEventCatalogExample.run(output)
    output.to_s.lines.should eq [
      "Unfurl https://example.com/tickets/42 in C-SYNTHETIC (C-SYNTHETIC.unfurl)",
      "Welcome U-NEWCOMER to C-SYNTHETIC, invited by U-INVITER",
      "Topic of C-SYNTHETIC is now Release week",
      "Message subtype synthetic_future_subtype in C-SYNTHETIC",
      "Rate limited for T-SYNTHETIC since 2026-09-12T17:00:00Z",
    ]
  end

  it "routes signed assistant thread and agent session events" do
    output = IO::Memory.new
    OfflineAssistantEventsExample.run(output)
    output.to_s.lines.should eq [
      "Thread 1789232400.000100 in D-ASSISTANT opened while U-ASKER views C-VIEWED",
      "Thread 1789232400.000100 now views no channel",
      "Thread root 1789232400.000100 titled Trip planning",
      "Viewing C-VIEWED",
      "Session 1789232400.000500 renamed to Bora Bora trip prep",
      "Stop work in C-AGENT 1789232400.000500; streams stopped: 1",
    ]
  end

  it "decodes Socket Mode frames and acknowledges each envelope" do
    output = IO::Memory.new
    acks = OfflineSocketModeExample.run(output)
    output.to_s.lines.should eq [
      "Connected as A-SYNTHETIC (1 of 10 connections)",
      "Mentioned in C-SYNTHETIC",
      "Command /request: test environment",
      "Rejected short reason",
      "Disconnect: refresh_requested",
    ]
    acks.map { |ack| JSON.parse(ack) }.should eq [
      JSON.parse(%({"envelope_id":"E-EVENT"})),
      JSON.parse(%({"envelope_id":"E-COMMAND"})),
      JSON.parse(%({"envelope_id":"E-SUBMIT","payload":{"response_action":"errors","errors":{"request.reason":"Explain why you need this request (at least 10 characters)."}}})),
    ]
  end

  it "receives a slash command over a Socket Mode connection and acknowledges it with a response" do
    output = IO::Memory.new
    finished = Channel(Array(String)).new(1)
    spawn { finished.send(OfflineSocketModeClientExample.run(output)) }
    acks = select
    when received = finished.receive
      received
    when timeout(5.seconds)
      fail "the Socket Mode client example did not stop"
    end
    output.to_s.lines.should eq ["Acknowledged /deploy staging", "Socket Mode is off; the client stopped"]
    acks.map { |ack| JSON.parse(ack) }.should eq [
      JSON.parse(%({"envelope_id":"E-DEPLOY","payload":{"response_type":"ephemeral","text":"Deploying staging"}})),
    ]
  end

  it "updates the clicked message from its container and reads submission and close context" do
    output = IO::Memory.new
    updated = OfflineInteractionContextExample.run(output)
    output.to_s.lines.should eq ["Approved in #releases at 1710000000.000100",
                                 "Share release-2.0 notes in C-ANNOUNCE (acknowledged 200)",
                                 "Closed all views of share_notes"]
    # Authored from Slack's chat.update reference, not from the serializer.
    updated.should eq JSON.parse(<<-JSON)
      {"channel":"C-RELEASES","ts":"1710000000.000100","text":"Release 2.0 approved.",
       "blocks":[{"type":"section","block_id":"decision.done","text":{"type":"mrkdwn","text":"*Release 2.0 approved.*"}}]}
      JSON
  end

  it "answers a signed slash command in the channel and replaces it through response_url" do
    output = IO::Memory.new
    result = OfflineSlashCommandExample.run(output)
    output.to_s.lines.should eq ["/deploy api 42 from U-SYNTHETIC", "Reported result through response_url"]
    result.acknowledgment.status_code.should eq 200
    result.acknowledgment.headers["Content-Type"].should eq "application/json"
    # Authored from Slack's slash command and response_url references, not from the serializer.
    JSON.parse(result.acknowledgment.body).should eq JSON.parse(<<-JSON)
      {"response_type":"in_channel","text":"Deploying api build 42.",
       "blocks":[{"type":"section","block_id":"deploy.status","text":{"type":"mrkdwn","text":"*Deploying api* build 42."}}]}
      JSON
    result.follow_up.should eq JSON.parse(%({"response_type":"in_channel","replace_original":true,"text":"Deployed api build 42."}))
  end

  it "reads the blocks of a clicked message, including container children and unknown types" do
    output = IO::Memory.new
    OfflineReceivedBlocksExample.run(output)
    output.to_s.lines.should eq ["Message 1710000000.000100",
                                 "header: Release 2.0",
                                 "section summary: *3* services change [release.more]",
                                 "container changes: Changes",
                                 "  rich_text notes: 1 element(s)",
                                 "actions decision: approve, reject",
                                 "skipped synthetic_future_block"]
  end

  it "serves a signed mention and a button click through the app receiver" do
    output = IO::Memory.new
    result = OfflineAppExample.run(output)
    output.to_s.lines.should eq ["Mention acknowledged: 200", "Click acknowledged: 200"]
    result.mention.body.should be_empty
    result.click.body.should be_empty
    # Authored from the chat.postMessage and Block Kit button references, not from the serializer.
    result.posts.should eq [JSON.parse(<<-JSON), JSON.parse(%({"channel":"C-DEPLOYS","text":"api approved by <@U-APPROVER>."}))]
      {"channel":"C-DEPLOYS","text":"Approve the api deploy?",
       "blocks":[{"type":"section","block_id":"deploy.summary","text":{"type":"mrkdwn","text":"Approve the *api* deploy?"}},
                 {"type":"actions","block_id":"deploy.controls",
                  "elements":[{"type":"button","text":{"type":"plain_text","text":"Approve"},"action_id":"deploy.approve","value":"api"}]}]}
      JSON
  end

  it "posts a custom step's approval button and completes the step from the click" do
    output = IO::Memory.new
    result = OfflineCustomStepExample.run(output)
    output.to_s.lines.should eq ["Step acknowledged: 200", "Click acknowledged: 200"]
    result.executed.body.should be_empty
    result.click.body.should be_empty
    # Authored from the chat.postMessage, Block Kit button, and functions.completeSuccess references.
    posted = JSON.parse(<<-JSON)
      {"channel":"C-APPROVALS","text":"Approve this request?",
       "blocks":[{"type":"actions","block_id":"approval.controls",
                  "elements":[{"type":"button","text":{"type":"plain_text","text":"Approve"},
                               "action_id":"approval.approve","value":"approve"}]}]}
      JSON
    completed = JSON.parse(%({"function_execution_id":"Fx-APPROVAL","outputs":{"approver_id":"U-APPROVER"}}))
    result.calls.should eq [
      OfflineCustomStepExample::Call.new("chat.postMessage", "Bearer xwfp-synthetic-step", posted),
      OfflineCustomStepExample::Call.new("functions.completeSuccess", "Bearer xwfp-synthetic-click", completed),
    ]
  end

  it "runs app listeners over Socket Mode and acknowledges with their responses" do
    output = IO::Memory.new
    finished = Channel(Array(String)).new(1)
    spawn { finished.send(OfflineSocketModeAppExample.run(output)) }
    acks = select
    when received = finished.receive
      received
    when timeout(5.seconds)
      fail "the Socket Mode app example did not stop"
    end
    output.to_s.lines.should eq ["Acknowledged 2 envelopes; Socket Mode is off"]
    # Authored from the Socket Mode, slash command response, and response_action references.
    acks.map { |ack| JSON.parse(ack) }.should eq [
      JSON.parse(%({"envelope_id":"E-DEPLOY","payload":{"response_type":"ephemeral","text":"Deploying api."}})),
      JSON.parse(%({"envelope_id":"E-SUBMIT","payload":{"response_action":"errors","errors":{"reason":"Enter at least 5 characters."}}})),
    ]
  end

  it "says in the command's channel and responds through its response_url" do
    output = IO::Memory.new
    result = OfflineAppExample.run_replies(output)
    output.to_s.lines.should eq ["Command acknowledged: 200", "Sent 2 replies"]
    result.acknowledgment.body.should be_empty
    post, response = result.requests
    # Authored from the chat.postMessage and response_url references, not from the serializer.
    post.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    post.headers["Authorization"].should eq "Bearer xoxb-synthetic-app"
    JSON.parse(post.body || "").should eq JSON.parse(%({"channel":"C-DEPLOYS","text":"Deploying api."}))
    response.uri.to_s.should eq "https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic"
    response.headers["Authorization"]?.should be_nil
    JSON.parse(response.body || "").should eq JSON.parse(%({"text":"Only you can see this: deploy queued."}))
  end

  it "reacts as the approving user and posts as the bot from one click" do
    output = IO::Memory.new
    result = OfflineAppExample.run_as_user(output)
    output.to_s.lines.should eq ["Click acknowledged: 200", "Reacted as the approver and posted as the bot"]
    reaction, post = result.requests
    # Authored from the reactions.add and chat.postMessage references, not from the serializer.
    reaction.uri.to_s.should eq "https://slack.com/api/reactions.add"
    reaction.headers["Authorization"].should eq "Bearer xoxp-synthetic-approver"
    JSON.parse(reaction.body || "").should eq JSON.parse(%({"channel":"C-DEPLOYS","name":"white_check_mark","timestamp":"1789232400.000200"}))
    post.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    post.headers["Authorization"].should eq "Bearer xoxb-synthetic-app"
    JSON.parse(post.body || "").should eq JSON.parse(%({"channel":"C-DEPLOYS","text":"api approved by <@U-APPROVER>."}))
  end

  it "greets an app thread and streams an answer with the stored thread context" do
    output = IO::Memory.new
    requests = OfflineAssistantExample.run(output)
    output.to_s.lines.should eq ["chat.postMessage", "assistant.threads.setSuggestedPrompts",
                                 "assistant.threads.setStatus", "conversations.replies", "conversations.replies",
                                 "chat.startStream", "chat.appendStream", "chat.stopStream"]
    requests.all? { |request| request.headers["Authorization"] == "Bearer xoxb-synthetic-assistant" }.should be_true
    bodies = requests.map { |request| request.body || "" }
    # Authored from the chat.postMessage, assistant.threads.*, and chat.*Stream references, not from the serializer.
    JSON.parse(bodies[0]).should eq JSON.parse(%({"channel":"D-ASSISTANT","text":"Hi! Ask me about a channel.","thread_ts":"1729999327.187299","metadata":{"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-SALES","team_id":"T-SYNTHETIC"}}}))
    JSON.parse(bodies[1]).should eq JSON.parse(%({"channel_id":"D-ASSISTANT","prompts":[{"title":"Summarize","message":"Summarize this channel."}]}))
    JSON.parse(bodies[2]).should eq JSON.parse(%({"channel_id":"D-ASSISTANT","thread_ts":"1729999327.187299","status":"is thinking..."}))
    JSON.parse(bodies[5]).should eq JSON.parse(%({"channel":"D-ASSISTANT","thread_ts":"1729999327.187299","recipient_user_id":"U-USER","recipient_team_id":"T-SYNTHETIC"}))
    JSON.parse(bodies[6]).should eq JSON.parse(%({"channel":"D-ASSISTANT","ts":"1729999501.000100","markdown_text":"Summary of <#C-SALES>: sales grew 4%."}))
    JSON.parse(bodies[7]).should eq JSON.parse(%({"channel":"D-ASSISTANT","ts":"1729999501.000100","session_status":"closed","metadata":{"event_type":"assistant_thread_context","event_payload":{"channel_id":"C-SALES","team_id":"T-SYNTHETIC"}}}))
  end
end
