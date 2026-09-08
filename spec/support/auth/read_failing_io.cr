# Delivers a JSON prefix, then simulates a transport read failure with unsafe text.
class AuthSupport::ReadFailingIO < IO
  @prefix = IO::Memory.new(%({"ok":true,"access_token":"synthetic-read-secret))

  def read(slice : Bytes) : Int32
    count = @prefix.read(slice)
    raise IO::Error.new("synthetic-read-secret") if count == 0
    count
  end

  def write(slice : Bytes) : NoReturn
    raise IO::Error.new("Read-only test stream")
  end
end
