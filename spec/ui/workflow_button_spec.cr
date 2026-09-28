require "../spec_helper"

module WorkflowButtonSpec
  alias UI = Slack::UI
  alias WorkflowButton = UI::BlockElements::WorkflowButton
  alias Workflow = UI::CompositionObjects::Workflow
  alias Trigger = UI::CompositionObjects::WorkflowTrigger
  alias Parameter = UI::CompositionObjects::WorkflowInputParameter

  class OnePassParameters
    include Enumerable(Parameter?)
    getter passes : Int32 = 0

    def each(&) : Nil
      @passes += 1
      raise "Traversed twice" if @passes > 1
      yield Parameter.new(name: "incident_id", value: "INC-7")
    end
  end

  def self.workflow(url : String = "https://slack.com/shortcuts/Ft0SYNTHETIC/run") : Workflow
    Workflow.new(trigger: Trigger.new(url: url))
  end

  describe WorkflowButton do
    it "serializes the documented trigger and input parameters independently of the wire fixture" do
      trigger = Trigger.new(url: "https://slack.com/shortcuts/Ft0123ABC456/xyz...zyx", customizable_input_parameters: {
        Parameter.new(name: "input_parameter_a", value: "Value for input param A"),
        Parameter.new(name: "input_parameter_b", value: "Value for input param B"),
      })
      button = WorkflowButton.new(text: UI.plain("Run Workflow", emoji: false), action_id: "workflowbutton123",
        workflow: Workflow.new(trigger: trigger), style: UI::BlockElements::ButtonStyle::Primary,
        accessibility_label: "Run the intake workflow")
      JSON.parse(button.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/workflow_button.json"))

      minimal = WorkflowButton.new(text: UI.plain("Run"), action_id: "", workflow: WorkflowButtonSpec.workflow)
      JSON.parse(minimal.to_json).should eq JSON.parse(<<-JSON)
        {"type":"workflow_button","text":{"type":"plain_text","text":"Run"},"action_id":"",
         "workflow":{"trigger":{"url":"https://slack.com/shortcuts/Ft0SYNTHETIC/run"}}}
        JSON
      empty = Trigger.new(url: "https://slack.com/shortcuts/Ft0SYNTHETIC/run", customizable_input_parameters: [] of Parameter)
      JSON.parse(empty.to_json)["customizable_input_parameters"].as_a.should be_empty
    end

    it "checks documented character limits and a present trigger URL" do
      WorkflowButton.new(text: UI.plain("界" * 75), action_id: "界" * 255, workflow: WorkflowButtonSpec.workflow,
        accessibility_label: "界" * 75).validate.should be_empty
      {
        "text.text"           => -> { WorkflowButton.new(text: UI.plain("界" * 76), action_id: "run", workflow: WorkflowButtonSpec.workflow) },
        "action_id"           => -> { WorkflowButton.new(text: UI.plain("Run"), action_id: "界" * 256, workflow: WorkflowButtonSpec.workflow) },
        "accessibility_label" => -> { WorkflowButton.new(text: UI.plain("Run"), action_id: "run", workflow: WorkflowButtonSpec.workflow, accessibility_label: "界" * 76) },
      }.each do |path, construct|
        expect_raises(UI::ValidationError) { construct.call }.issues.first.path.should eq path
      end
      error = expect_raises(UI::ValidationError) { Trigger.new(url: "") }
      error.issues.first.code.should eq "workflow_trigger.url.empty"
      error.issues.first.path.should eq "url"
    end

    it "fits Section and Actions on a message and rejects duplicate action IDs" do
      button = WorkflowButton.new(text: UI.plain("Run"), action_id: "run", workflow: WorkflowButtonSpec.workflow)
      message = UI.message(fallback_text: "Run") do |builder|
        builder.section(UI.plain("Run"), accessory: button)
        builder.actions({UI::BlockElements::Button.new(text: UI.plain("Skip"), action_id: "skip"), button})
      end
      wire = JSON.parse(message.to_json)
      wire["blocks"][0]["accessory"]["type"].should eq "workflow_button"
      wire["blocks"][1]["elements"][1]["type"].should eq "workflow_button"
      duplicate = UI::BlockElements::Button.new(text: UI.plain("Other"), action_id: "run")
      error = expect_raises(UI::ValidationError) { UI::Blocks::Actions.new({button, duplicate}) }
      error.issues.first.code.should eq "actions.action_id.duplicate"
    end

    it "rejects Home and modal surfaces because Slack documents messages only" do
      button = WorkflowButton.new(text: UI.plain("Run"), action_id: "run", workflow: WorkflowButtonSpec.workflow)
      {
        "home"  => UI::HomeBuilder.new,
        "modal" => UI::DisplayModalBuilder.new(title: UI.plain("Run")),
      }.each do |surface, builder|
        builder.section(UI.plain("Run"), accessory: button)
        builder.actions({UI::BlockElements::Button.new(text: UI.plain("Skip"), action_id: "skip"), button})
        issues = expect_raises(UI::ValidationError) { builder.build }.issues
        issues.map { |issue| {issue.code, issue.path} }.should eq [
          {"#{surface}.workflow_button.unsupported_surface", "blocks[0].accessory"},
          {"#{surface}.workflow_button.unsupported_surface", "blocks[1].elements[1]"},
        ]
      end
      form = UI::FormModalBuilder.new(title: UI.plain("Run"), submit: UI.plain("Save"))
      form.actions({button})
      expect_raises(UI::ValidationError) { form.build }.issues.first.code.should eq "modal.workflow_button.unsupported_surface"
    end

    it "copies supported yielded parameters once even when the declared item type includes nil" do
      source = OnePassParameters.new
      trigger = Trigger.new(url: "https://slack.com/shortcuts/Ft0SYNTHETIC/run", customizable_input_parameters: source)
      trigger.customizable_input_parameters.try(&.clear)
      trigger.customizable_input_parameters.try(&.map(&.name)).should eq ["incident_id"]
      source.passes.should eq 1
      Trigger.new(url: "https://slack.com/shortcuts/Ft0SYNTHETIC/run").customizable_input_parameters.should be_nil
    end
  end
end
