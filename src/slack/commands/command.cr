# Models events sent by Slack slash commands. Slack allow for slash commands to
# optionally encode or declode usernames, channel names, and other data.
#
# To learn more, see the Slack API documentation:
# [Slack Commands API](https://api.slack.com/interactivity/slash-commands)
struct Slack::Command
  record PlainTextReference, name : String
  record EncodedTextReference, id : String, name : String

  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer api_app_id : String,
    channel_id : String,
    command : String,
    enterprise_id : String?,
    response_url : String,
    team_id : String,
    text : String,
    trigger_id : String,
    user_id : String,
    channel_name : String,
    enterprise_name : String?,
    team_name : String?,
    user_name : String

  # Escaped usernames in text will often be formatted with the user_id and
  # the username encoded ```<@U012ABCDEF|worf>```).
  #
  # Slack is phasing these out, so apps should only rely on the ID, not the
  # user_name + separator, long-term. Those that aren't being phased out are
  # treated as "unreliable" -- meaning they change frequently and are mostly
  # decorators.
  #
  # More info available at Slack:
  # [The One About Usernames](https://api.slack.com/changelog/2017-09-the-one-about-usernames)
  def decoded_usernames : Array(EncodedTextReference)
    text.scan(/<@(?<id>\w+)(?:\|(?<name>[^>]+))?>/).map do |match|
      EncodedTextReference.new(id: match["id"], name: match["name"])
    end
  end

  # If an app is configured to not escape usernames in text fields, the format
  # usernames will be presented as will be @username, or @user_name for a user
  # with a space in their username. A space signifies the end of a username.
  def plaintext_usernames : Array(PlainTextReference)
    text.scan(/(^|[^<])@(?<name>\S+)/).map do |match|
      PlainTextReference.new(name: match["name"])
    end
  end

  # If an app is configured to not escape channels in text fields, the format
  # channels will be presented as will be @channel, or @channel-with-dashes.
  # A space signifies the end of a channel name.
  def plaintext_channels : Array(PlainTextReference)
    text.scan(/(^|[^<])#(?<name>\S+)/).map do |match|
      PlainTextReference.new(name: match["name"])
    end
  end

  # Escaped channels may include the channel name and ID with a bar separator:
  # ```<@C2147483705|channel-name>```.
  #
  def decoded_channels : Array(EncodedTextReference)
    text.scan(/<#(?<id>\w+)(?:\|(?<name>[^>]+))?>/).map do |match|
      EncodedTextReference.new(id: match["id"], name: match["name"])
    end
  end
end
