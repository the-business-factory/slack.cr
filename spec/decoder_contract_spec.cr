require "./spec_helper"

# The contract that every `Slack::Decoder` meets. `DecoderContract.verify`
# defines the examples for one decoder, so a second decoder runs the same
# examples with one more call at the end of this file.
#
# A decoded payload re-encodes to the input when the two JSON values are
# equivalent. Two JSON values are equivalent when:
#
# - Two scalars are equal. JSON value equality ignores key order and
#   whitespace.
# - Two arrays have the same size and equivalent items in the same order.
# - For each key of two objects, one of these is true:
#   - Both values are present and equivalent. A `null` value is the same as
#     an absent key, because the typed models omit a `nil` field.
#   - Only the output has the key, and its value is `false` or `[]`: the
#     default of a field that Slack left out.
#   - Only the input has the key, and `KNOWN_DIFFERENCES` lists the path.
#
# Any other difference fails the example. A listed difference that does not
# occur also fails, so the list stays current when a model gains a field.
module DecoderContract
  extend Spec::Methods

  FIXTURES = "spec/fixtures"

  # Known differences between the input and the re-encoded output, by fixture.
  KNOWN_DIFFERENCES = {
    # Typed models keep only the fields they declare. Only `Events::Unknown`,
    # `Message::Unmapped`, and `Interactions::Unknown` keep unknown keys
    # (decision 10: no `JSON::Serializable::Unmapped` on typed events).
    "events/app_home_opened.json"                      => ["$.event.event_ts: dropped"],
    "events/app_mention_thread.json"                   => ["$.event.client_msg_id: dropped"],
    "events/message/assistant_app_thread_changed.json" => [
      "$.event.message.edited: dropped",
      "$.event.message.is_locked: dropped",
      "$.event.message.latest_reply: dropped",
      "$.event.message.reply_count: dropped",
      "$.event.message.reply_users: dropped",
      "$.event.message.reply_users_count: dropped",
      "$.event.message.thread_ts: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
      "$.event.previous_message.is_locked: dropped",
      "$.event.previous_message.latest_reply: dropped",
      "$.event.previous_message.reply_count: dropped",
      "$.event.previous_message.reply_users: dropped",
      "$.event.previous_message.reply_users_count: dropped",
      "$.event.previous_message.thread_ts: dropped",
      "$.event.previous_message.type: dropped",
      "$.event.previous_message.user: dropped",
    ],
    "events/message/bot_message.json"  => ["$.event.icons: dropped"],
    "events/message/channel_join.json" => ["$.event.user: dropped"],
    "events/message/file_share.json"   => [
      "$.event.client_msg_id: dropped",
      "$.event.display_as_bot: dropped",
      "$.event.upload: dropped",
    ],
    "events/message/message_changed.json" => [
      "$.event.message.attachments[2].image_bytes: dropped",
      "$.event.message.attachments[2].image_height: dropped",
      "$.event.message.attachments[2].image_url: dropped",
      "$.event.message.attachments[2].image_width: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
      "$.event.previous_message.type: dropped",
      "$.event.previous_message.user: dropped",
    ],
    "events/message/message_replied.json" => [
      "$.event.message.replies: dropped",
      "$.event.message.reply_count: dropped",
      "$.event.message.thread_ts: dropped",
      "$.event.message.type: dropped",
      "$.event.message.user: dropped",
    ],
    "events/subteam_members_changed.json" => [
      "$.event.added_users_count: dropped",
      "$.event.date_previous_update: dropped",
      "$.event.date_update: dropped",
      "$.event.removed_users_count: dropped",
    ],
    "events/thread_broadcast.json" => [
      "$.event.blocks: dropped",
      "$.event.client_msg_id: dropped",
      "$.event.text: dropped",
      "$.event.user: dropped",
    ],
    # A workflow token is a secret. The models read it but do not write it,
    # so logs and `to_json` output do not show it.
    "events/function_executed.json"                 => ["$.event.bot_access_token: dropped"],
    "interactions/block_actions_view_function.json" => ["$.bot_access_token: dropped"],
    # `Slack::Command` does not model the deprecated verification token or
    # `team_domain`, and it decodes `is_enterprise_install` to a `Bool`.
    "commands/encoded_names.txt" => [
      "$.is_enterprise_install: \"false\\n\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
    "commands/unencoded_names.txt" => [
      "$.is_enterprise_install: \"false\\n\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
    "socket_mode/slash_commands.json" => [
      "$.is_enterprise_install: \"false\" became false",
      "$.team_domain: dropped",
      "$.token: dropped",
    ],
  }

  # The error that each malformed fixture raises: the class, the message, and
  # for `Slack::Auth::RequestAuthorizationError` the reason.
  MALFORMED = {
    "malformed/events/truncated.json" => <<-ERROR,
      JSON::ParseException: Unexpected token: <EOF> at line 1, column 100
      ERROR
    "malformed/events/array_body.json" => <<-ERROR,
      JSON::ParseException: Expected BeginObject but was BeginArray at line 1, column 2
      ERROR
    "malformed/events/missing_event.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: event
        parsing Slack::VerifiedEvent#event at line 1, column 1
      ERROR
    "malformed/events/app_mention_numeric_ts.json" => <<-ERROR,
      JSON::SerializableError: Expected String but was Int at line 1, column 84
        parsing Slack::Events::AppMentioned#ts at line 1, column 69
        parsing Slack::VerifiedEvent#event at line 5, column 3
      ERROR
    "malformed/events/channel_topic_missing_topic.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: topic
        parsing Slack::Events::Message::ChannelTopic#topic at line 1, column 1
        parsing Slack::VerifiedEvent#event at line 5, column 3
      ERROR
    "malformed/events/url_verification_missing_challenge.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: challenge
        parsing Slack::UrlVerification#challenge at line 1, column 1
      ERROR
    "malformed/interactions/missing_type.json" => <<-ERROR,
      JSON::SerializableError: Missing string JSON discriminator field 'type'
        parsing Slack::Interaction at line 1, column 1
      ERROR
    "malformed/interactions/block_actions_string_user.json" => <<-ERROR,
      JSON::SerializableError: Expected BeginObject but was String at line 1, column 119
        parsing Slack::Interactions::User at line 1, column 106
        parsing Slack::Interactions::BlockAction#user at line 1, column 99
      ERROR
    "malformed/interactions/unknown_empty_user.json" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: id
        parsing Slack::Interactions::User#id at line 1, column 1
      ERROR
    "malformed/interactions/duplicate_payload.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_payload)
      ERROR
    "malformed/commands/duplicate_team_id.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (duplicate_routing_field)
      ERROR
    "malformed/commands/invalid_install_kind.txt" => <<-ERROR,
      Slack::Auth::RequestAuthorizationError: Authentication failure: InvalidIdentity (invalid_install_kind)
      ERROR
    "malformed/commands/missing_command.txt" => <<-ERROR,
      JSON::SerializableError: Missing JSON attribute: command
        parsing Slack::Command#command at line 1, column 1
      ERROR
  }

  def self.verify(decoder : Slack::Decoder) : Nil
    describe "#{decoder.class} decoder contract" do
      describe "re-encodes each event fixture" do
        event_fixtures.each do |path|
          it path do
            body = read(path)
            assert_round_trip(path, body, decoder.event(body))
          end
        end

        it "socket_mode/events_api_app_mention.json" do
          body = socket_mode_payload("socket_mode/events_api_app_mention.json")
          assert_round_trip("socket_mode/events_api_app_mention.json", body, decoder.event(body))
        end
      end

      describe "re-encodes each interaction fixture as a form and as JSON" do
        interaction_fixtures.each do |path|
          it path do
            body = read(path)
            assert_round_trip(path, body, decoder.interaction(form_payload(body)))
            assert_round_trip(path, body, decoder.interaction(body, :json))
          end
        end

        it "socket_mode/interactive_block_actions.json" do
          body = socket_mode_payload("socket_mode/interactive_block_actions.json")
          assert_round_trip("socket_mode/interactive_block_actions.json", body, decoder.interaction(body, :json))
        end
      end

      describe "re-encodes each slash command fixture" do
        Dir.glob("#{FIXTURES}/commands/*.txt").sort.each do |file|
          path = relative(file)
          it path do
            body = read(path)
            assert_round_trip(path, form_as_json(body), decoder.command(body))
          end
        end

        it "socket_mode/slash_commands.json" do
          body = socket_mode_payload("socket_mode/slash_commands.json")
          assert_round_trip("socket_mode/slash_commands.json", body, decoder.command(body, :json))
        end
      end

      describe "raises the same error for each malformed fixture" do
        MALFORMED.each do |path, expected|
          it path do
            decode_malformed(decoder, path).each do |error|
              describe_error(error).should eq(expected)
            end
          end
        end
      end
    end
  end

  # Returns the differences between *input* and *output*, sorted. See the
  # module documentation for the rules.
  def self.differences(input : JSON::Any, output : JSON::Any) : Array(String)
    differences = [] of String
    collect(input, output, "$", differences)
    differences.sort
  end

  private def self.collect(input : JSON::Any, output : JSON::Any, path : String, differences : Array(String)) : Nil
    input_object = input.as_h?
    output_object = output.as_h?
    return collect_object(input_object, output_object, path, differences) if input_object && output_object

    input_array = input.as_a?
    output_array = output.as_a?
    return collect_array(input_array, output_array, path, differences) if input_array && output_array

    differences << "#{path}: #{input.to_json} became #{output.to_json}" unless input == output
  end

  private def self.collect_object(input : Hash(String, JSON::Any), output : Hash(String, JSON::Any),
                                  path : String, differences : Array(String)) : Nil
    (input.keys | output.keys).each do |key|
      input_value = present(input, key)
      output_value = present(output, key)
      key_path = "#{path}.#{key}"
      if input_value && output_value
        collect(input_value, output_value, key_path, differences)
      elsif input_value
        differences << "#{key_path}: dropped"
      elsif output_value && !default?(output_value)
        differences << "#{key_path}: added #{output_value.to_json}"
      end
    end
  end

  private def self.collect_array(input : Array(JSON::Any), output : Array(JSON::Any),
                                 path : String, differences : Array(String)) : Nil
    return differences << "#{path}: #{input.size} items became #{output.size}" unless input.size == output.size

    input.each_with_index do |item, index|
      collect(item, output[index], "#{path}[#{index}]", differences)
    end
  end

  private def self.present(object : Hash(String, JSON::Any), key : String) : JSON::Any?
    value = object[key]?
    value unless value.nil? || value.raw.nil?
  end

  private def self.default?(value : JSON::Any) : Bool
    value.raw == false || value.as_a?.try(&.empty?) || false
  end

  private def self.assert_round_trip(path : String, input : String, decoded : JSON::Serializable) : Nil
    actual = differences(JSON.parse(input), JSON.parse(decoded.to_json))
    actual.should eq(KNOWN_DIFFERENCES.fetch(path, [] of String).sort)
  end

  private def self.decode_malformed(decoder : Slack::Decoder, path : String) : Array(Exception)
    body = read(path)
    kind = path.split('/')[1]
    case {kind, File.extname(path)}
    when {"events", ".json"}       then [capture { decoder.event(body) }]
    when {"interactions", ".json"} then [capture { decoder.interaction(form_payload(body)) }, capture { decoder.interaction(body, :json) }]
    when {"interactions", ".txt"}  then [capture { decoder.interaction(body) }]
    when {"commands", ".txt"}      then [capture { decoder.command(body) }]
    else                                raise ArgumentError.new("No decode rule for #{path}")
    end
  end

  private def self.capture(&) : Exception
    yield
  rescue error
    error
  else
    fail "Expected the payload not to decode"
  end

  private def self.describe_error(error : Exception) : String
    description = "#{error.class}: #{error.message}"
    return description unless error.is_a?(Slack::Auth::RequestAuthorizationError)

    "#{description} (#{error.reason})"
  end

  private def self.event_fixtures : Array(String)
    Dir.glob(
      "#{FIXTURES}/events/**/*.json",
      "#{FIXTURES}/credential_lifecycle/*.json",
      "#{FIXTURES}/request_authorizer/event_*.json",
    ).sort.map { |file| relative(file) }
  end

  private def self.interaction_fixtures : Array(String)
    Dir.glob(
      "#{FIXTURES}/interactions/*.json",
      "#{FIXTURES}/request_authorizer/interaction_*.json",
      "#{FIXTURES}/block_kit/*_action.json",
      "#{FIXTURES}/block_kit/phase_5_submission.json",
    ).sort.map { |file| relative(file) }
  end

  private def self.relative(file : String) : String
    file.lchop("#{FIXTURES}/")
  end

  private def self.read(path : String) : String
    File.read("#{FIXTURES}/#{path}")
  end

  # Returns the payload that `SocketModeReceiver` gives the decoder.
  private def self.socket_mode_payload(path : String) : String
    envelope = Slack::SocketMode::Frame.parse(read(path)).should be_a(Slack::SocketMode::Envelope)
    envelope.payload_json
  end

  # Returns an HTTP interaction body: *json* in the one `payload` field.
  private def self.form_payload(json : String) : String
    URI::Params.encode({"payload" => json})
  end

  # Returns the fields of a slash command form as a JSON object of strings.
  private def self.form_as_json(body : String) : String
    object = {} of String => String
    URI::Params.parse(body).each { |key, value| object[key] = value }
    object.to_json
  end
end

DecoderContract.verify(Slack::Decoder.default)
