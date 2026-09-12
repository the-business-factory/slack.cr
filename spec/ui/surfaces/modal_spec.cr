require "../../spec_helper"

describe Slack::UI::Modal do
  it "accepts modal labels at 23 and 24 characters and rejects 25" do
    Slack::UI::Modal::Title.new("t" * 23)
    Slack::UI::Modal::Title.new("t" * 24)
    Slack::UI::Modal::Submit.new("s" * 23)
    Slack::UI::Modal::Submit.new("s" * 24)
    Slack::UI::Modal::Close.new("c" * 23)
    Slack::UI::Modal::Close.new("c" * 24)

    errmsg = "Text cannot be longer than 24 characters."
    expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
      Slack::UI::Modal::Title.new("t" * 25)
    end
    expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
      Slack::UI::Modal::Submit.new("s" * 25)
    end
    expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
      Slack::UI::Modal::Close.new("c" * 25)
    end
  end

  it "counts Unicode labels by characters" do
    Slack::UI::Modal::Title.new("✓" * 24)

    expect_raises(
      Slack::Errors::InvalidUIBlock,
      "Text cannot be longer than 24 characters."
    ) do
      Slack::UI::Modal::Title.new("✓" * 25)
    end
  end

  it "omits submit and close for a modal without input blocks" do
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Details")
    )
    blocks = [section] of Slack::TypeAliases::ModalBlock
    payload = JSON.parse(
      Slack::UI::Modal.new(
        title: Slack::UI::Modal::Title.new("Details"),
        blocks: blocks
      ).to_json
    )

    payload["type"].as_s.should eq "modal"
    payload.as_h.has_key?("submit").should be_false
    payload.as_h.has_key?("close").should be_false
  end

  it "requires submit when the modal contains an input block" do
    input = Slack::UI::Blocks::Input.new(
      label: Slack::UI::Blocks::Input::Label.new("Notes"),
      element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "notes")
    )
    blocks = [input] of Slack::TypeAliases::ModalBlock

    expect_raises(
      Slack::Errors::InvalidUIBlock,
      "Modal submit is required when blocks include an input"
    ) do
      Slack::UI::Modal.new(
        title: Slack::UI::Modal::Title.new("Notes"),
        blocks: blocks
      )
    end
  end

  it "allows input blocks with submit and omits an absent close" do
    input = Slack::UI::Blocks::Input.new(
      label: Slack::UI::Blocks::Input::Label.new("Notes"),
      element: Slack::UI::BlockElements::PlainTextInput.new(action_id: "notes")
    )
    blocks = [input] of Slack::TypeAliases::ModalBlock
    payload = JSON.parse(
      Slack::UI::Modal.new(
        title: Slack::UI::Modal::Title.new("Notes"),
        submit: Slack::UI::Modal::Submit.new("Save"),
        blocks: blocks
      ).to_json
    )

    payload["submit"]["text"].as_s.should eq "Save"
    payload.as_h.has_key?("close").should be_false
  end

  it "preserves the legacy positional constructor order" do
    section = Slack::UI::Blocks::Section.new(
      text: Slack::UI::Blocks::Section::Text.new("Details")
    )
    blocks = [section] of Slack::TypeAliases::ModalBlock
    payload = JSON.parse(
      Slack::UI::Modal.new(
        blocks,
        Slack::UI::Modal::Close.new("Cancel"),
        Slack::UI::Modal::Submit.new("Save"),
        Slack::UI::Modal::Title.new("Details")
      ).to_json
    )

    payload["blocks"].as_a.size.should eq 1
    payload["close"]["text"].as_s.should eq "Cancel"
    payload["submit"]["text"].as_s.should eq "Save"
    payload["title"]["text"].as_s.should eq "Details"
  end
end
