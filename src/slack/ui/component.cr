abstract class Slack::UI::Component
  include Slack::UI::BaseComponents
  include Slack::JSONRecords
end

abstract class Slack::UI::BaseComponent < Slack::UI::Component
end

# Slack::UI::CustomComponent allows for app-specific UI components to be built,
# leveraging Base Components, Blocks, Block Elements, and the Block Kit API.
abstract class Slack::UI::CustomComponent < Slack::UI::Component
end
