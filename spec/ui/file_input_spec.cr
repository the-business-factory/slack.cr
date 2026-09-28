require "../../spec_helper"

module FileInputSpec
  alias UI = Slack::UI::Checked
  alias Element = UI::BlockElements::FileInput

  describe Element do
    it "serializes the independent file_input contract and omits unset fields" do
      element = Element.new(action_id: "receipts", filetypes: {"pdf", "png"}, max_files: 3)
      JSON.parse(element.to_json).should eq JSON.parse(%({"type":"file_input","action_id":"receipts","filetypes":["pdf","png"],"max_files":3}))
      JSON.parse(Element.new.to_json).should eq JSON.parse(%({"type":"file_input"}))
    end

    it "checks the documented file count range and local extension policy" do
      {1, 10}.each { |count| Element.new(max_files: count).validate.should be_empty }
      {0, 11, -1}.each do |count|
        error = expect_raises(UI::ValidationError) { Element.new(max_files: count) }
        error.issues.first.path.should eq "max_files"
        error.issues.first.code.should eq "file_input.max_files.out_of_range"
      end
      expect_raises(UI::ValidationError) { Element.new(filetypes: [] of String) }.issues.first.code.should eq "file_input.filetypes.empty"
      error = expect_raises(UI::ValidationError) { Element.new(filetypes: {"pdf", ""}) }
      error.issues.first.path.should eq "filetypes[1]"
      error.issues.first.code.should eq "file_input.filetypes.blank"
      Element.new(action_id: "界" * 255).validate.should be_empty
      expect_raises(UI::ValidationError) { Element.new(action_id: "界" * 256) }.issues.first.path.should eq "action_id"
    end

    it "owns a snapshot of the supplied extensions" do
      source = ["pdf"]
      element = Element.new(filetypes: source)
      source << "exe"
      element.filetypes.should_not(be_nil) << "zip"
      element.filetypes.should eq ["pdf"]
      JSON.parse(element.to_json)["filetypes"].should eq JSON.parse(%(["pdf"]))
    end
  end

  describe UI::Blocks::ModalInput do
    it "places a file input only in a form modal and rejects a dispatch request" do
      builder = UI::FormModalBuilder.new(title: UI.plain("Receipts"), submit: UI.plain("Send"))
      builder.input(label: UI.plain("Receipts"), element: Element.new(action_id: "files"), block_id: "receipts",
        hint: UI.plain("PDF only"), optional: true, dispatch_action: false)
      builder.input(label: UI.plain("Note"), element: UI::BlockElements::PlainTextInput.new(focus_on_load: true))
      JSON.parse(builder.build.to_json)["blocks"][0].should eq JSON.parse(<<-JSON)
        {"type":"input","label":{"type":"plain_text","text":"Receipts"},"block_id":"receipts",
         "hint":{"type":"plain_text","text":"PDF only"},"optional":true,"dispatch_action":false,
         "element":{"type":"file_input","action_id":"files"}}
        JSON
      error = expect_raises(UI::ValidationError) { UI::Blocks::ModalInput.new(label: UI.plain("Files"), element: Element.new, dispatch_action: true) }
      error.issues.first.path.should eq "dispatch_action"
      error.issues.first.code.should eq "input.dispatch_action.unsupported"
      expect_raises(UI::ValidationError) { UI::Blocks::ModalInput.new(label: UI.plain("界" * 2001), element: Element.new) }.issues.first.path.should eq "label.text"
      blocks = [UI::Blocks::ModalInput.new(label: UI.plain("Files"), element: Element.new, block_id: "same"),
                UI::Blocks::ModalInput.new(label: UI.plain("More"), element: Element.new, block_id: "same")]
      error = expect_raises(UI::ValidationError) { UI::FormModal.new(title: UI.plain("Files"), submit: UI.plain("Send"), blocks: blocks) }
      error.issues.first.path.should eq "blocks[1].block_id"
    end
  end
end
