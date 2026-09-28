require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::BotsInfo do
  it "sends the bot and team and reads the bot" do
    WebMock.stub(:post, "https://slack.com/api/bots.info")
      .with(body: "bot=B123456&team_id=T1", headers: {"Authorization" => "Bearer xoxb-synthetic"})
      .to_return(body: <<-JSON)
        {"ok":true,"bot":{"id":"B123456","deleted":false,"name":"beforebot","updated":1449272004,
         "app_id":"A123456","user_id":"U123456",
         "icons":{"image_36":"https://icons.example.test/36.png","image_48":"https://icons.example.test/48.png",
                  "image_72":"https://icons.example.test/72.png"}}}
        JSON

    bot = ApiSupport.client.call(Slack::Api::BotsInfo.new(bot: "B123456", team_id: "T1")).bot

    bot.id.should eq "B123456"
    bot.name.should eq "beforebot"
    bot.app_id.should eq "A123456"
    bot.user_id.should eq "U123456"
    bot.deleted?.should be_false
    bot.updated.should eq 1449272004
    icons = bot.icons.should_not be_nil
    icons["image_72"].should eq "https://icons.example.test/72.png"
  end
end
