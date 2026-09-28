# :nodoc:
# The prepared lifecycle deliveries of this process by event ID, so that a
# repeated delivery applies its original preparation and never captures the
# grants of a later installation. Holds the most recent `CAPACITY` events.
class Slack::App::LifecycleHistory
  CAPACITY = 1_000

  @deliveries = {} of String => Slack::Auth::PreparedLifecycleDelivery
  @mutex = Mutex.new

  # Returns the retained preparation of *event_id*. Otherwise retains and
  # returns the block's result; a nil result retains nothing. The block runs
  # under the lock, so concurrent duplicates share one preparation.
  def fetch(event_id : String, & : -> Slack::Auth::PreparedLifecycleDelivery?) : Slack::Auth::PreparedLifecycleDelivery?
    @mutex.synchronize do
      @deliveries[event_id]? || yield.try { |delivery| retain(event_id, delivery) }
    end
  end

  private def retain(event_id : String, delivery : Slack::Auth::PreparedLifecycleDelivery) : Slack::Auth::PreparedLifecycleDelivery
    @deliveries.shift if @deliveries.size >= CAPACITY
    @deliveries[event_id] = delivery
  end
end
