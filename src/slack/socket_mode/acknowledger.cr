# Acknowledges one `Envelope`. `Client#run` gives one to the handler with each
# envelope. Call `#ack` once, within three seconds of receipt.
#
# ```
# client.run do |envelope, ack|
#   ack.ack
#   handle(envelope)
# end
# ```
class Slack::SocketMode::Acknowledger
  getter envelope_id : String
  @acknowledged = Atomic(Bool).new(false)

  # :nodoc:
  def initialize(envelope : Envelope, @outbox : Channel(Acknowledgment))
    @envelope_id = envelope.envelope_id
    @accepts_response_payload = envelope.accepts_response_payload?
  end

  def acknowledged? : Bool
    @acknowledged.get
  end

  # Queues the acknowledgment, with *payload* when given. The client sends it
  # on its current connection.
  #
  # Raises `AcknowledgmentError` when the envelope is already acknowledged,
  # when *payload* is given but the envelope does not accept one, or when the
  # client has stopped.
  def ack(payload : Acknowledgment::Payload? = nil) : Nil
    if payload && !@accepts_response_payload
      raise AcknowledgmentError.new("Envelope #{@envelope_id} does not accept a response payload")
    end
    _, first = @acknowledged.compare_and_set(false, true)
    raise AcknowledgmentError.new("Envelope #{@envelope_id} is already acknowledged") unless first

    begin
      @outbox.send(Acknowledgment.new(@envelope_id, payload))
    rescue Channel::ClosedError
      raise AcknowledgmentError.new("The Socket Mode client stopped before envelope #{@envelope_id} was acknowledged")
    end
  end
end
