# Icons for `IconButton`. Slack documents `trash` as the only icon.
enum Slack::UI::BlockElements::IconButtonIcon
  Trash

  def wire_value : String
    case self
    in .trash? then "trash"
    end
  end
end
