require "../spec_helper"

module ExternalSelectSpec
  alias UI = Slack::UI
  alias Single = UI::BlockElements::ExternalSelect
  alias Multi = UI::BlockElements::MultiExternalSelect

  class OnePassOptions
    include Enumerable(UI::CompositionObjects::Option?)
    getter passes : Int32 = 0

    def initialize(@items : Array(UI::CompositionObjects::Option))
    end

    def each(&) : Nil
      @passes += 1
      raise "Traversed twice" if @passes > 1
      @items.each { |item| yield item }
    end
  end

  def self.option(value : String) : UI::CompositionObjects::Option
    UI::CompositionObjects::Option.new(text: UI.plain(value.capitalize), value: value)
  end

  describe "External selects" do
    it "serializes independently authored single and multiple external contracts" do
      confirm = UI::CompositionObjects::Confirmation.new(title: UI.plain("Assign?"),
        text: UI.plain("Assign this project"), confirm: UI.plain("Yes"), deny: UI.plain("No"))
      single = Single.new(action_id: "project", placeholder: UI.plain("Find project", emoji: false),
        initial_option: option("apollo"), min_query_length: 0, confirm: confirm, focus_on_load: false)
      JSON.parse(single.to_json).should eq JSON.parse(<<-JSON)
        {"type":"external_select","action_id":"project","placeholder":{"type":"plain_text","text":"Find project","emoji":false},
         "initial_option":{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"},"min_query_length":0,"focus_on_load":false,
         "confirm":{"title":{"type":"plain_text","text":"Assign?"},"text":{"type":"plain_text","text":"Assign this project"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      multi = Multi.new(action_id: "projects", placeholder: UI.plain("Find projects"),
        initial_options: {option("apollo"), option("gemini")}, min_query_length: 2, max_selected_items: 2,
        confirm: confirm, focus_on_load: true)
      JSON.parse(multi.to_json).should eq JSON.parse(<<-JSON)
        {"type":"multi_external_select","action_id":"projects","placeholder":{"type":"plain_text","text":"Find projects"},
         "initial_options":[{"text":{"type":"plain_text","text":"Apollo"},"value":"apollo"},{"text":{"type":"plain_text","text":"Gemini"},"value":"gemini"}],
         "min_query_length":2,"max_selected_items":2,"focus_on_load":true,
         "confirm":{"title":{"type":"plain_text","text":"Assign?"},"text":{"type":"plain_text","text":"Assign this project"},"confirm":{"type":"plain_text","text":"Yes"},"deny":{"type":"plain_text","text":"No"}}}
        JSON
      JSON.parse(Single.new.to_json).should eq JSON.parse(%({"type":"external_select"}))
      JSON.parse(Multi.new.to_json).should eq JSON.parse(%({"type":"multi_external_select"}))
    end

    it "places external selects in Section, Actions and Input on every surface" do
      message = UI.message(fallback_text: "Projects") do |builder|
        builder.section(UI.plain("Project"), block_id: "pick", accessory: Single.new(action_id: "project"))
        builder.actions(block_id: "more", elements: {Multi.new(action_id: "projects")})
        builder.input(label: UI.plain("Owner project"), block_id: "owner", element: Single.new(action_id: "owned"))
      end
      JSON.parse(message.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"section","block_id":"pick","text":{"type":"plain_text","text":"Project"},"accessory":{"type":"external_select","action_id":"project"}},
         {"type":"actions","block_id":"more","elements":[{"type":"multi_external_select","action_id":"projects"}]},
         {"type":"input","block_id":"owner","label":{"type":"plain_text","text":"Owner project"},"element":{"type":"external_select","action_id":"owned"}}]
        JSON
      home = UI.home do |builder|
        builder.actions(elements: {Single.new(action_id: "project")})
      end
      JSON.parse(home.to_json)["blocks"][0]["elements"][0]["type"].should eq "external_select"
      form = UI.form_modal(title: UI.plain("Projects"), submit: UI.plain("Save")) do |builder|
        builder.input(label: UI.plain("Projects"), element: Multi.new(action_id: "projects"))
      end
      JSON.parse(form.to_json)["blocks"][0]["element"]["type"].should eq "multi_external_select"
    end

    it "participates in the single view focus rule" do
      expect_raises(UI::ValidationError) do
        UI.form_modal(title: UI.plain("Projects"), submit: UI.plain("Save")) do |builder|
          builder.input(label: UI.plain("One"), element: Single.new(action_id: "one", focus_on_load: true))
          builder.actions(elements: {Multi.new(action_id: "two", focus_on_load: true)})
        end
      end
    end

    it "rejects documented limits and library selection policies" do
      {
        -> { Single.new(action_id: "a" * 256) }                                              => "action_id",
        -> { Single.new(placeholder: UI.plain("p" * 151)) }                                  => "placeholder.text",
        -> { Single.new(min_query_length: -1) }                                              => "min_query_length",
        -> { Multi.new(min_query_length: -1) }                                               => "min_query_length",
        -> { Multi.new(max_selected_items: 0) }                                              => "max_selected_items",
        -> { Multi.new(initial_options: [] of UI::CompositionObjects::Option) }              => "initial_options",
        -> { Multi.new(initial_options: {option("a"), option("b")}, max_selected_items: 1) } => "initial_options",
        -> { Multi.new(initial_options: {option("a"), option("a")}) }                        => "initial_options[1]",
      }.each do |build, path|
        expect_raises(UI::ValidationError) { build.call }.issues.map(&.path).should contain(path)
      end
    end

    it "owns initial options after one traversal and returns copies" do
      items = [option("apollo"), option("gemini")]
      source = OnePassOptions.new(items)
      multi = Multi.new(initial_options: source)
      items.clear
      multi.initial_options.should_not(be_nil).clear
      source.passes.should eq 1
      JSON.parse(multi.to_json)["initial_options"].as_a.map(&.["value"].as_s).should eq ["apollo", "gemini"]
    end
  end
end
