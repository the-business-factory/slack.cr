require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::EmojiList do
  it "returns custom emoji images and aliases" do
    WebMock.stub(:post, "https://slack.com/api/emoji.list")
      .with(body: "")
      .to_return(body: <<-JSON)
        {"ok":true,"emoji":{"bowtie":"https://my.slack.com/emoji/bowtie/46ec6f2bb0.png",
         "squirrel":"https://my.slack.com/emoji/squirrel/f35f40c0e0.png","shipit":"alias:squirrel"}}
        JSON

    list = ApiSupport.client.call(Slack::Api::EmojiList.new)

    list.emoji.should eq({
      "bowtie"   => "https://my.slack.com/emoji/bowtie/46ec6f2bb0.png",
      "squirrel" => "https://my.slack.com/emoji/squirrel/f35f40c0e0.png",
      "shipit"   => "alias:squirrel",
    })
    list.alias_target("shipit").should eq "squirrel"
    list.alias_target("bowtie").should be_nil
    list.alias_target("missing").should be_nil
    list.categories.should be_nil
  end

  it "requests Unicode categories and keeps them as raw JSON" do
    WebMock.stub(:post, "https://slack.com/api/emoji.list")
      .with(body: "include_categories=true")
      .to_return(body: <<-JSON)
        {"ok":true,"emoji":{},"categories_version":"5",
         "categories":[{"name":"smileys_people","emoji_names":["grinning","smiley"]}]}
        JSON

    list = ApiSupport.client.call(Slack::Api::EmojiList.new(include_categories: true))

    list.emoji.should be_empty
    categories = list.categories.should_not be_nil
    categories[0]["emoji_names"].as_a.map(&.as_s).should eq ["grinning", "smiley"]
  end
end
