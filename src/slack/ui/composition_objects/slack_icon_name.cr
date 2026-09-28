# The icon names that Slack documents for the Slack icon object. Each member
# sends its kebab-case name, for example `CaretLeft` sends `caret-left`.
enum Slack::UI::Checked::CompositionObjects::SlackIconName
  Archive
  Book
  Bookmark
  Bot
  Bug
  Calendar
  Call
  CaretLeft
  CaretRight
  Check
  Clipboard
  Code
  Comment
  Compass
  Copy
  Cube
  Download
  Edit
  Email
  EyeClosed
  EyeOpen
  File
  Flag
  Folder
  Gear
  Globe
  Heart
  Help
  Image
  Info
  Key
  Lightbulb
  Link
  Map
  Mobile
  NewWindow
  Pin
  Plus
  Refine
  Refresh
  Rocket
  Save
  Screen
  Share
  Sparkle
  Star
  StarFilled
  Tag
  ThumbsDown
  ThumbsUp
  Trash
  Upload
  User
  Warning

  def wire_value : String
    to_s.underscore.tr("_", "-")
  end
end
