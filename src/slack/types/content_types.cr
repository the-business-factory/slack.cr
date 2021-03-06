module Slack
  enum ContentTypes
    FormEncoded
    JSON

    def to_s
      case self
      when .form_encoded?
        "application/x-www-form-urlencoded"
      when .json?
        "application/json; charset=utf-8"
      else
        raise "Content type not supported."
      end
    end
  end
end
