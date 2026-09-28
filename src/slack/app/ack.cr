# :nodoc:
# The single-use acknowledgment slot of one request. The first `#complete` or
# the deadline in `#wait` claims it; later claims fail. Only the claimant sends,
# so the buffered channel never blocks a sender and gets at most one value.
class Slack::App::Ack
  @claimed = Atomic(Bool).new(false)
  @channel = Channel(Outcome).new(1)

  # Returns false when the request already has an outcome.
  def complete(outcome : Outcome) : Bool
    return false unless claim
    @channel.send(outcome)
    true
  end

  # Completes, then yields so the waiting receiver writes the response before
  # the listener continues. A send to a waiting fiber only schedules it.
  def respond(outcome : Outcome) : Bool
    return false unless complete(outcome)
    Fiber.yield
    true
  end

  # Waits for the outcome. Returns nil when *timeout* passes first; the slot is
  # then claimed, so a later `#complete` returns false.
  def wait(timeout : Time::Span) : Outcome?
    select
    when outcome = @channel.receive
      outcome
    when timeout(timeout)
      # A sender that claimed the slot just before the deadline has sent or will send.
      claim ? nil : @channel.receive
    end
  ensure
    @channel.close
  end

  private def claim : Bool
    !@claimed.swap(true)
  end
end
