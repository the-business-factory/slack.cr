module Slack::Auth
  class WriteTrackingIO < IO
    getter? application_write_started : Bool = false

    def initialize(@io : IO)
    end

    def read(slice : Bytes) : Int32
      @io.read(slice)
    end

    def write(slice : Bytes) : Nil
      @application_write_started = true
      @io.write(slice)
    end

    def flush : Nil
      @io.flush
    end

    def close : Nil
      @io.close
    end

    def closed? : Bool
      @io.closed?
    end
  end
end
