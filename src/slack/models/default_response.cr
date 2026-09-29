# Used for Slack response objects that only include { ok: true }.
struct Slack::Models::DefaultResponse < Slack::Model
  include Slack::Api::Envelope
end
