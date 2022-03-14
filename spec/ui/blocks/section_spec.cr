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
  end
end
