require "json"

module Slack::Models
  # A Slack user group. See https://docs.slack.dev/reference/methods/usergroups.create.
  #
  # `users` is present only when the request asks for users; `user_count` only
  # when it sets `include_count`. Unknown fields are ignored.
  struct Usergroup
    include JSON::Serializable

    # :nodoc:
    # The default channels of a group.
    struct Prefs
      include JSON::Serializable

      getter channels : Array(String) = [] of String
    end

    # :nodoc:
    # Slack sends `user_count` as a JSON string in its documented examples and
    # as a number in other responses. Both read as `Int32`; it writes a number.
    module CountConverter
      def self.from_json(pull : JSON::PullParser) : Int32
        case pull.kind
        when .string? then pull.read_string.to_i
        else               pull.read_int.to_i32
        end
      end

      def self.to_json(value : Int32, json : JSON::Builder) : Nil
        json.number(value)
      end
    end

    getter id : String
    getter team_id : String
    getter name : String
    getter handle : String
    getter description : String?
    getter? is_external : Bool = false
    # `admin` or `owner` for groups that Slack maintains; otherwise nil.
    getter auto_type : String?
    getter date_create : Int64
    getter date_update : Int64
    # Unix time when the group was disabled; 0 while it is enabled.
    getter date_delete : Int64 = 0_i64
    getter created_by : String?
    getter updated_by : String?
    getter deleted_by : String?
    getter users : Array(String)?
    @[JSON::Field(converter: Slack::Models::Usergroup::CountConverter)]
    getter user_count : Int32?
    @prefs : Prefs?

    def enabled? : Bool
      @date_delete == 0
    end

    # The IDs of the default channels.
    def channels : Array(String)
      @prefs.try(&.channels.dup) || [] of String
    end
  end
end
