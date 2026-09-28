# :nodoc:
# Builds display blocks through the concrete surface builder's typed add method.
module Slack::UI::DisplayBlockHelpers
  def section(
    text : Slack::UI::CompositionObjects::Text,
    accessory : Slack::UI::Blocks::Section::Accessory? = nil,
    block_id : String? = nil,
    expand : Bool? = nil,
  ) : Nil
    add(Slack::UI::Blocks::Section.new(
      text: text,
      accessory: accessory,
      block_id: block_id,
      expand: expand
    ))
  end

  def actions(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Slack::UI::Blocks::Actions.new(elements: elements, block_id: block_id))
  end

  def divider(block_id : String? = nil) : Nil
    add(Slack::UI::Blocks::Divider.new(block_id: block_id))
  end

  def header(text : CompositionObjects::PlainText, block_id : String? = nil, level : Int32? = nil) : Nil
    add(Blocks::Header.new(text: text, block_id: block_id, level: level))
  end

  def context(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::Context.new(elements: elements, block_id: block_id))
  end

  def rich_text(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Blocks::RichText.new(elements: elements, block_id: block_id))
  end

  def image(*, alt_text : String, image_url : String, title : CompositionObjects::PlainText? = nil, block_id : String? = nil) : Nil
    add(Blocks::Image.new(alt_text: alt_text, image_url: image_url, title: title, block_id: block_id))
  end

  def image(*, alt_text : String, slack_file : CompositionObjects::SlackFile, title : CompositionObjects::PlainText? = nil, block_id : String? = nil) : Nil
    add(Blocks::Image.new(alt_text: alt_text, slack_file: slack_file, title: title, block_id: block_id))
  end

  def video(
    *,
    alt_text : String,
    title : CompositionObjects::PlainText,
    thumbnail_url : String,
    video_url : String,
    title_url : String? = nil,
    description : CompositionObjects::PlainText? = nil,
    author_name : String? = nil,
    provider_name : String? = nil,
    provider_icon_url : String? = nil,
    block_id : String? = nil,
  ) : Nil
    add(Blocks::Video.new(
      alt_text: alt_text, title: title, thumbnail_url: thumbnail_url, video_url: video_url,
      title_url: title_url, description: description, author_name: author_name,
      provider_name: provider_name, provider_icon_url: provider_icon_url, block_id: block_id
    ))
  end
end
