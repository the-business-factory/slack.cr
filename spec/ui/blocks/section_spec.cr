require "../../spec_helper"

describe Slack::UI::Blocks::Section do
  describe "text length validations" do
    it "should raise an error if the text is too long" do
      errmsg = "Text cannot be longer than 3000 characters."
      expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
        Slack::UI::Components::TextSection.render("t" * 3001)
      end
    end

    it "should have a max length of 2000 when using fields" do
      errmsg = "Text cannot be longer than 2000 characters."
      expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
        ft = Slack::UI::Blocks::Section::FieldText.new("t" * 2001)
        Slack::UI::Blocks::Section.new(fields: [ft])
      end
    end

    it "renders the expected json with text" do
      Slack::UI::Components::TextSection.render("Hi").to_json.should eq(
        {
          "type": "section",
          "text": {
            "type":  "plain_text",
            "text":  "Hi",
            "emoji": false,
          },
        }.to_json
      )
    end

    it "renders the expected json with fields" do
      ft = Slack::UI::Blocks::Section::FieldText.new("Hi")
      json = Slack::UI::Blocks::Section.new(fields: [ft]).to_json
      json.should eq({
        "type":   "section",
        "fields": [ft],
      }.to_json)
    end

    it "renders the expected json with text and fields" do
      text = Slack::UI::Blocks::Section::Text.new("Hi")
      ft = Slack::UI::Blocks::Section::FieldText.new("Hi")
      json = Slack::UI::Blocks::Section.new(text: text, fields: [ft]).to_json
      json.should eq(
        {
          "type": "section",
          "text": {
            "type":  "plain_text",
            "text":  "Hi",
            "emoji": false,
          },
          "fields": [{
            "type":  "plain_text",
            "text":  "Hi",
            "emoji": false,
          }],
        }.to_json
      )
    end

    it "serializes block_id and omits it only when absent" do
      text = Slack::UI::Blocks::Section::Text.new("Hi")
      with_id = JSON.parse(
        Slack::UI::Blocks::Section.new(text: text, block_id: "summary").to_json
      )
      without_id = JSON.parse(Slack::UI::Blocks::Section.new(text: text).to_json)

      with_id["block_id"].as_s.should eq "summary"
      without_id.as_h.has_key?("block_id").should be_false
    end

    it "accepts block IDs at 254 and 255 characters and rejects 256" do
      text = Slack::UI::Blocks::Section::Text.new("Hi")
      below = Slack::UI::Blocks::Section.new(text: text, block_id: "i" * 254)
      at = Slack::UI::Blocks::Section.new(text: text, block_id: "i" * 255)

      JSON.parse(below.to_json)["block_id"].as_s.size.should eq 254
      JSON.parse(at.to_json)["block_id"].as_s.size.should eq 255
      expect_raises(
        Slack::Errors::InvalidUIBlock,
        "Block ID cannot be longer than 255 characters"
      ) do
        Slack::UI::Blocks::Section.new(text: text, block_id: "i" * 256)
      end
    end

    it "counts Unicode block IDs by characters" do
      text = Slack::UI::Blocks::Section::Text.new("Hi")
      Slack::UI::Blocks::Section.new(text: text, block_id: "✓" * 255)

      expect_raises(
        Slack::Errors::InvalidUIBlock,
        "Block ID cannot be longer than 255 characters"
      ) do
        Slack::UI::Blocks::Section.new(text: text, block_id: "✓" * 256)
      end
    end

    it "rejects an overlong block ID assigned through the retained setter" do
      section = Slack::UI::Blocks::Section.new(
        text: Slack::UI::Blocks::Section::Text.new("Hi")
      )
      section.block_id = "i" * 256

      expect_raises(
        Slack::Errors::InvalidUIBlock,
        "Block ID cannot be longer than 255 characters"
      ) do
        section.to_json
      end
    end

    it "rejects an empty fields collection even when text is present" do
      text = Slack::UI::Blocks::Section::Text.new("Hi")
      errmsg = "Fields must have at least one text object"

      expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
        Slack::UI::Blocks::Section.new(text: text, fields: [] of Slack::UI::Blocks::Section::FieldText)
      end
    end

    it "should not raise an error with proper field length" do
      ft = Slack::UI::Blocks::Section::FieldText.new("t" * 2000)
      Slack::UI::Blocks::Section.new(fields: [ft])
    end

    it "should not allow fields with more than 10 text fields" do
      errmsg = "Fields can include a max of 10 text objects"
      expect_raises(Slack::Errors::InvalidUIBlock, errmsg) do
        ft = Array.new(11) { Slack::UI::Blocks::Section::FieldText.new("t") }
        Slack::UI::Blocks::Section.new(fields: ft)
      end
    end

    it "should not raise an error for the correct size" do
      Slack::UI::Components::TextSection.render("t" * 3000)
    end

    it "accepts values just below the text and fields limits" do
      Slack::UI::Components::TextSection.render("t" * 2999)
      field = Slack::UI::Blocks::Section::FieldText.new("t" * 1999)
      Slack::UI::Blocks::Section.new(fields: Array.new(9, field))
      Slack::UI::Blocks::Section.new(fields: Array.new(10, field))
    end
  end
end
