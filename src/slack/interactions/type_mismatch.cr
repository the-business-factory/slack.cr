# Raised by typed interaction accessors; raw payloads remain available.
class Slack::Interactions::TypeMismatch < Exception
  getter path : String
  getter expected : String
  getter actual : String

  def initialize(@path : String, @expected : String, @actual : String)
    super("#{@path}: expected #{@expected}, got #{@actual}.")
  end
end
