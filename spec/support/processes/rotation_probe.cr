require "../rotation/helpers"
require "../storage/durable_store"
require "../storage/file_clock"
require "../storage/process_helpers"

module SpecSupport
  # :nodoc:
  # One rotation contender. `rotate` refreshes through a transport that waits
  # for the parent's `finish` file before it answers; `read` only acquires.
  module RotationProbe
    def self.run(directory : String, action : String, identity : String) : Nil
      clock = StorageSupport::FileClock.new(File.join(directory, "clock"))
      store = StorageSupport::DurableStore.new(directory, clock)
      transport = RotationSupport::Transport.new
      transport.before_response = -> {
        File.write(File.join(directory, "sent-#{identity}"), "one synthetic refresh")
        StorageSupport.await_file(File.join(directory, "finish"))
        nil
      }
      service = RotationSupport.service(store, transport, clock)
      File.write(File.join(directory, "ready-#{identity}"), "ready")
      StorageSupport.await_file(File.join(directory, "start-#{identity}"))
      reference = action == "read" ? store.acquire(RotationSupport.query) : service.rotate(RotationSupport.query)
      token = store.credential_for_dispatch(reference)
      File.write(File.join(directory, "result-#{identity}"), token.value)
    rescue error : Slack::Auth::ContractError
      File.write(File.join(directory, "result-#{identity}"), error.code.to_s)
    end
  end
end
