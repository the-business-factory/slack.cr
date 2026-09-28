# Slack shows `Default` when an alert omits its level.
enum Slack::UI::Checked::Blocks::AlertLevel
  Default
  Info
  Warning
  Error
  Success

  def wire_value : String
    case self
    in .default? then "default"
    in .info?    then "info"
    in .warning? then "warning"
    in .error?   then "error"
    in .success? then "success"
    end
  end
end
