# :nodoc:
# Holds the registered listeners in registration order and returns the first
# one whose constraints match a payload.
class Slack::App::Router
  @routes = [] of Route

  def listener(payload : App::Payload, environment : Environment) : Listener?
    @routes.each do |route|
      if listener = route.listener(payload, environment)
        return listener
      end
    end
  end

  # Adds a route that another type builds, such as an `Assistant` route.
  def add(route : Route) : Nil
    @routes << route
  end

  # Matches events that are a *T*, for example `Slack::Events::AppMentioned`.
  def event(event_type : T.class, middleware : Array(Middleware), handler : Proc(EventContext(T), Nil)) : Nil forall T
    @routes << TypedRoute(EventContext(T)).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      event = payload.event
      EventContext(T).new(environment, payload, event) if event.is_a?(T)
    end
  end

  # Matches events of a *type* that this library does not map.
  def unknown_event(type : String, middleware : Array(Middleware),
                    handler : Proc(EventContext(Slack::Events::Unknown), Nil)) : Nil
    @routes << TypedRoute(EventContext(Slack::Events::Unknown)).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      event = payload.event
      if event.is_a?(Slack::Events::Unknown) && event.type == type
        EventContext(Slack::Events::Unknown).new(environment, payload, event)
      end
    end
  end

  def message(pattern : (String | Regex)?, middleware : Array(Middleware),
              handler : Proc(EventContext(Slack::Events::Message), Nil)) : Nil
    @routes << TypedRoute(EventContext(Slack::Events::Message)).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      message = payload.event
      if message.is_a?(Slack::Events::Message) && text_matches?(pattern, message.text)
        EventContext(Slack::Events::Message).new(environment, payload, message)
      end
    end
  end

  def function(callback_id : String, middleware : Array(Middleware), handler : Proc(FunctionContext, Nil)) : Nil
    @routes << TypedRoute(FunctionContext).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      event = payload.event
      if event.is_a?(Slack::Events::FunctionExecuted) && event.function.callback_id == callback_id
        FunctionContext.new(environment, payload, event)
      end
    end
  end

  # Matches actions that are a *T*. *T* is `Slack::Interactions::Action` for every action type.
  def action(action_type : T.class, action_id : String | Regex | Slack::UI::ActionId, block_id : String?,
             middleware : Array(Middleware), handler : Proc(ActionContext(T), Nil)) : Nil forall T
    pattern = action_pattern(action_id)
    @routes << TypedRoute(ActionContext(T)).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      next unless payload.is_a?(Slack::Interactions::BlockAction)
      action = payload.actions.first?
      if action.is_a?(T) && matches?(pattern, action_id(action)) && (block_id.nil? || block_id == block_id(action))
        ActionContext(T).new(environment, payload, action)
      end
    end
  end

  def command(name : String, middleware : Array(Middleware), handler : Proc(CommandContext, Nil)) : Nil
    @routes << TypedRoute(CommandContext).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      CommandContext.new(environment, payload) if payload.is_a?(Slack::Command) && payload.command == name
    end
  end

  def shortcut(callback_id : String | Regex, middleware : Array(Middleware),
               handler : Proc(ShortcutContext, Nil)) : Nil
    @routes << TypedRoute(ShortcutContext).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      case payload
      when Slack::Interactions::Shortcut, Slack::Interactions::MessageAction
        ShortcutContext.new(environment, payload) if matches?(callback_id, payload.callback_id)
      end
    end
  end

  def options(action_id : String | Regex | Slack::UI::ActionId, middleware : Array(Middleware), handler : Proc(OptionsContext, Nil)) : Nil
    pattern = action_pattern(action_id)
    @routes << TypedRoute(OptionsContext).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      if payload.is_a?(Slack::Interactions::BlockSuggestion) && matches?(pattern, payload.action_id)
        OptionsContext.new(environment, payload)
      end
    end
  end

  def view(callback_id : String | Regex, middleware : Array(Middleware), handler : Proc(ViewContext, Nil)) : Nil
    @routes << TypedRoute(ViewContext).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      if payload.is_a?(Slack::Interactions::ViewSubmission) && matches?(callback_id, payload.view.try(&.callback_id))
        ViewContext.new(environment, payload)
      end
    end
  end

  def view_closed(callback_id : String | Regex, middleware : Array(Middleware),
                  handler : Proc(ViewClosedContext, Nil)) : Nil
    @routes << TypedRoute(ViewClosedContext).new(middleware, handler, acknowledge_first: false) do |payload, environment|
      if payload.is_a?(Slack::Interactions::ViewClosed) && matches?(callback_id, payload.view.try(&.callback_id))
        ViewClosedContext.new(environment, payload)
      end
    end
  end

  private def action_pattern(action_id : String | Regex | Slack::UI::ActionId) : String | Regex
    action_id.is_a?(Slack::UI::ActionId) ? action_id.value : action_id
  end

  # A string matches the whole value; a regex matches anywhere in it.
  private def matches?(pattern : String | Regex, value : String?) : Bool
    return false unless value
    pattern.is_a?(Regex) ? pattern.matches?(value) : pattern == value
  end

  # Message text patterns follow Bolt: a string matches when the text contains it.
  private def text_matches?(pattern : (String | Regex)?, text : String) : Bool
    return true unless pattern
    case pattern
    in String then text.includes?(pattern)
    in Regex  then pattern.matches?(text)
    end
  end

  private def action_id(action : Slack::Interactions::Action) : String?
    case action
    when Slack::Interactions::UnknownAction then action.raw["action_id"]?.try(&.as_s?)
    else                                         action.action_id
    end
  end

  private def block_id(action : Slack::Interactions::Action) : String?
    case action
    when Slack::Interactions::UnknownAction then action.raw["block_id"]?.try(&.as_s?)
    else                                         action.block_id
    end
  end
end
