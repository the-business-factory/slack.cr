require "../spec_helper"

module PlanTaskCardSpec
  alias UI = Slack::UI

  def self.rich_text(text : String) : UI::Blocks::RichText
    UI::Blocks::RichText.new(elements: {UI::RichText::Section.new(elements: {UI::RichText::Text.new(text)})})
  end

  def self.task(task_id : String, title : String = "Task", status : UI::TaskStatus = UI::TaskStatus::Complete) : UI::Blocks::TaskCard
    UI::Blocks::TaskCard.new(task_id: task_id, title: title, status: status)
  end

  def self.issues(error : UI::ValidationError) : Array(Tuple(String, String))
    error.issues.map { |issue| {issue.code, issue.path} }
  end

  describe UI::Blocks::Plan do
    it "serializes a plan whose tasks have three statuses in a message" do
      message = UI.message(fallback_text: "User report") do |builder|
        builder.plan(title: "Thinking completed", block_id: "plan.report", tasks: {
          UI::Blocks::TaskCard.new(task_id: "call_001", title: "Fetched user profile information",
            status: UI::TaskStatus::InProgress, details: rich_text("Searched database..."),
            output: rich_text("Profile data loaded")),
          UI::Blocks::TaskCard.new(task_id: "call_002", title: "Checked user permissions", status: UI::TaskStatus::Pending),
          UI::Blocks::TaskCard.new(task_id: "call_003", title: "Generated comprehensive user report",
            status: UI::TaskStatus::Complete, output: rich_text("15 data points compiled")),
        })
      end

      JSON.parse(message.to_json).should eq JSON.parse(<<-JSON)
        {"text":"User report","blocks":[{
          "type":"plan","title":"Thinking completed","block_id":"plan.report",
          "tasks":[
            {"type":"task_card","task_id":"call_001","title":"Fetched user profile information","status":"in_progress",
             "details":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Searched database..."}]}]},
             "output":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Profile data loaded"}]}]}},
            {"type":"task_card","task_id":"call_002","title":"Checked user permissions","status":"pending"},
            {"type":"task_card","task_id":"call_003","title":"Generated comprehensive user report","status":"complete",
             "output":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"15 data points compiled"}]}]}}
          ]}]}
        JSON
    end

    it "accepts 50 tasks and rejects 51, an empty list, duplicate task IDs, and an empty title" do
      UI::Blocks::Plan.new(title: "Fifty", tasks: (1..50).map { |index| task("task_#{index}") }).tasks.size.should eq 50

      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Plan.new(title: "Too many", tasks: (1..51).map { |index| task("task_#{index}") })
      end
      issues(error).should eq [{"plan.tasks.too_many", "tasks"}]

      error = expect_raises(UI::ValidationError) { UI::Blocks::Plan.new(title: "Empty", tasks: [] of UI::Blocks::TaskCard) }
      issues(error).should eq [{"plan.tasks.empty", "tasks"}]

      error = expect_raises(UI::ValidationError) do
        UI::Blocks::Plan.new(title: "", tasks: {task("read"), task("write"), task("read")})
      end
      issues(error).should eq [{"plan.title.empty", "title"}, {"plan.task_id.duplicate", "tasks[2].task_id"}]
    end

    it "owns a copy of its tasks" do
      tasks = [task("read")]
      plan = UI::Blocks::Plan.new(title: "Plan", tasks: tasks)
      tasks << task("write")
      plan.tasks << task("extra")

      plan.tasks.map(&.task_id).should eq ["read"]
    end
  end

  describe UI::Blocks::TaskCard do
    it "serializes a standalone task card with sources in a message" do
      sources = [
        UI::BlockElements::UrlSource.new(url: "https://weather.com/", text: "weather.com"),
        UI::BlockElements::UrlSource.new(url: "https://www.accuweather.com/", text: "accuweather.com"),
      ]
      card = UI::Blocks::TaskCard.new(task_id: "task_1", title: "Fetching weather data",
        status: UI::TaskStatus::InProgress, output: rich_text("Found weather data for Chicago from 2 sources"),
        sources: sources, hide_title: false, block_id: "weather")
      sources.clear
      message = UI::Message.with_slack_generated_fallback(blocks: {card})

      JSON.parse(message.to_json).should eq JSON.parse(<<-JSON)
        {"blocks":[{"type":"task_card","task_id":"task_1","title":"Fetching weather data","status":"in_progress",
          "output":{"type":"rich_text","elements":[{"type":"rich_text_section","elements":[{"type":"text","text":"Found weather data for Chicago from 2 sources"}]}]},
          "sources":[{"type":"url","url":"https://weather.com/","text":"weather.com"},
                     {"type":"url","url":"https://www.accuweather.com/","text":"accuweather.com"}],
          "hide_title":false,"block_id":"weather"}]}
        JSON
    end

    it "rejects an empty task ID, an empty title, and a long block ID" do
      error = expect_raises(UI::ValidationError) do
        UI::Blocks::TaskCard.new(task_id: "", title: "", status: UI::TaskStatus::Error, block_id: "b" * 256)
      end
      issues(error).should eq [
        {"task_card.task_id.empty", "task_id"},
        {"task_card.title.empty", "title"},
        {"task_card.block_id.too_long", "block_id"},
      ]
    end

    it "shares the message block ID space at the top level" do
      error = expect_raises(UI::ValidationError) do
        UI::Message.with_slack_generated_fallback(blocks: {
          UI::Blocks::TaskCard.new(task_id: "one", title: "One", status: UI::TaskStatus::Complete, block_id: "task"),
          UI::Blocks::Plan.new(title: "Plan", tasks: {task("two")}, block_id: "task"),
        })
      end
      issues(error).should eq [{"message.block_id.duplicate", "blocks[1].block_id"}]
    end
  end
end
