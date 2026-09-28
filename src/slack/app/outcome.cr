# The result of `Slack::App#dispatch` for one request. A receiver turns it into
# its transport response, for example an HTTP status and JSON body.
struct Slack::App::Outcome
  enum Status
    # A listener acknowledged, the listener returned, no listener matched, or the
    # acknowledgment deadline passed. `#json` holds the body, if any.
    Acknowledged
    # The authorizer could not produce a client. No listener ran.
    Unauthorized
    # Routing or a listener raised before the request was acknowledged.
    Failed
  end

  getter status : Status
  getter body : AckBody?
  # The body as JSON, encoded and validated when the outcome is created.
  getter json : String?

  def self.acknowledged(body : AckBody? = nil) : self
    new(Status::Acknowledged, body)
  end

  def self.unauthorized : self
    new(Status::Unauthorized)
  end

  def self.failed : self
    new(Status::Failed)
  end

  private def initialize(@status : Status, @body : AckBody? = nil)
    @json = body.try(&.to_json)
  end
end
