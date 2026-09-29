# Raised when received JSON does not have the expected shape, for example by a
# typed payload accessor or by `SocketMode::Frame.parse`. `#path` names the
# field. Raw payloads remain available.
class Slack::TypeMismatch < Exception
  getter path : String
  getter expected : String
  getter actual : String

  def initialize(@path : String, @expected : String, @actual : String)
    super("#{@path}: expected #{@expected}, got #{@actual}.")
  end
end
