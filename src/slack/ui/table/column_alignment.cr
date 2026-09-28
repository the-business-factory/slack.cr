enum Slack::UI::Table::ColumnAlignment
  Left
  Center
  Right

  def wire_value : String
    case self
    in .left?   then "left"
    in .center? then "center"
    in .right?  then "right"
    end
  end
end
