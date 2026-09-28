require "../spec_helper"

describe "received file input state" do
  it "decodes independently authored uploaded files and keeps unknown fields raw" do
    submission = Slack::Interaction.from_json(<<-JSON).should be_a(Slack::Interactions::ViewSubmission)
      {"type":"view_submission","view":{"callback_id":"expense","state":{"values":{
        "receipts":{"files":{"type":"file_input","files":[
          {"id":"F-ONE","created":1710000000,"timestamp":1710000000,"name":"receipt.pdf","title":"receipt.pdf",
           "mimetype":"application/pdf","filetype":"pdf","user":"U-ONE","size":1024,
           "url_private":"https://files.slack.com/files-pri/T-ONE-F-ONE/receipt.pdf",
           "url_private_download":"https://files.slack.com/files-pri/T-ONE-F-ONE/download/receipt.pdf",
           "permalink":"https://example.slack.com/files/U-ONE/F-ONE/receipt.pdf"},
          {"id":"F-TWO","name":null}]}},
        "note":{"text":{"type":"plain_text_input","value":"Travel"}}}}}}
      JSON
    state = submission.state_map
    value = state.file_input_value?("receipts", "files").should_not be_nil
    value.type.should eq "file_input"
    value.files_presence.should eq Slack::Interactions::ValuePresence::Present
    files = value.files.should_not be_nil
    files.map(&.id).should eq ["F-ONE", "F-TWO"]
    receipt = files.first
    receipt.name.should eq "receipt.pdf"
    receipt.title.should eq "receipt.pdf"
    receipt.mimetype.should eq "application/pdf"
    receipt.filetype.should eq "pdf"
    receipt.url_private.should eq "https://files.slack.com/files-pri/T-ONE-F-ONE/receipt.pdf"
    receipt.url_private_download.should eq "https://files.slack.com/files-pri/T-ONE-F-ONE/download/receipt.pdf"
    receipt.raw["size"].as_i.should eq 1024
    files[1].name.should be_nil
    files[1].url_private.should be_nil
    files.clear
    value.files.should_not(be_nil).size.should eq 2
    state.file_input_value?("receipts", "missing").should be_nil
    expect_raises(Slack::Interactions::TypeMismatch) { state.file_input_value?("note", "text") }.path.should eq %(view.state.values["note"]["text"])
    expect_raises(Slack::Interactions::TypeMismatch) { state.plain_text_value?("receipts", "files") }.path.should eq %(view.state.values["receipts"]["files"])
  end

  it "preserves absent, null and empty file lists" do
    {"" => Slack::Interactions::ValuePresence::Absent, %(,"files":null) => Slack::Interactions::ValuePresence::Null,
     %(,"files":[]) => Slack::Interactions::ValuePresence::Present}.each do |field, presence|
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"file_input"#{field}}}}})))
      value = map.file_input_value?("b", "a").should_not be_nil
      value.files_presence.should eq presence
      value.files.should eq(presence.present? ? [] of Slack::Interactions::UploadedFile : nil)
    end
  end

  it "rejects wrong JSON types with paths while leaving file_input actions unknown" do
    { %("files":{}) => "files", %("files":[null]) => "files[0]", %("files":[{"name":"x"}]) => "files[0].id",
     %("files":[{"id":7}]) => "files[0].id", %("files":[{"id":"F","mimetype":[]}]) => "files[0].mimetype" }.each do |field, path|
      map = Slack::Interactions::StateMap.new(JSON.parse(%({"values":{"b":{"a":{"type":"file_input",#{field}}}}})))
      expect_raises(Slack::Interactions::TypeMismatch) { map["b", "a"]? }.path.should eq %(state.values["b"]["a"].#{path})
    end
    # Slack documents no block_actions dispatch for file_input; an unexpected one stays raw.
    actions = Slack::Interactions::ActionDecoder.decode(JSON.parse(%([{"type":"file_input","block_id":"b","action_id":"a","files":[]}])))
    actions.first.should be_a(Slack::Interactions::UnknownAction)
  end
end
