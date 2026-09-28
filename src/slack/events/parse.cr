require "json"

module Slack::Events
  # Decodes verified Events API bytes. A `url_verification` request becomes a
  # `Slack::UrlVerification`; every other request becomes a `Slack::VerifiedEvent`.
  # Pass only a body that `Slack::Webhooks::Verifier#verify` returned.
  def self.parse(body : String) : Slack::VerifiedEvent | Slack::UrlVerification
    if envelope_type(body) == "url_verification"
      Slack::UrlVerification.from_json(body)
    else
      Slack::VerifiedEvent.from_json(body)
    end
  end

  private def self.envelope_type(body : String) : String?
    type = nil
    pull = JSON::PullParser.new(body)
    pull.read_object do |key|
      if key == "type" && pull.kind.string?
        type = pull.read_string
      else
        pull.skip
      end
    end
    type
  end
end
