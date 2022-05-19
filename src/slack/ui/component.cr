module Slack::UI::Component
  include Slack::UI::BaseComponents
  include Slack::JSONRecords
end

abstract struct Slack::UI::BaseComponent
  include Slack::UI::Component
end

# Slack::UI::CustomComponent allows for app-specific UI components to be built,
# leveraging Base Components, Blocks, Block Elements, and the Block Kit API.
abstract struct Slack::UI::CustomComponent
  include Slack::UI::Component
end
