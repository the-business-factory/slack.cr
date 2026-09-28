require "../../spec_helper"

private alias VideoUI = Slack::UI::Checked

private def minimal_video(**overrides) : VideoUI::Blocks::Video
  VideoUI::Blocks::Video.new(**{
    alt_text:      "Walkthrough",
    title:         VideoUI.plain("Walkthrough"),
    thumbnail_url: "https://videos.example.test/thumb.jpg",
    video_url:     "https://videos.example.test/embed/1",
  }.merge(overrides))
end

describe "Checked video block" do
  it "serializes every documented field" do
    video = VideoUI::Blocks::Video.new(
      alt_text: "Release 4.2 walkthrough",
      title: VideoUI.plain("Release 4.2 walkthrough", emoji: true),
      title_url: "https://videos.example.test/watch/release-4-2",
      description: VideoUI.plain("What changed in release 4.2."),
      thumbnail_url: "https://videos.example.test/thumbs/release-4-2.jpg",
      video_url: "https://videos.example.test/embed/release-4-2?autoplay=1",
      author_name: "Release team",
      provider_name: "Example Video",
      provider_icon_url: "https://videos.example.test/icon.png",
      block_id: "release.video"
    )
    JSON.parse(video.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/video.json"))
  end

  it "omits optional fields" do
    JSON.parse(minimal_video.to_json).should eq JSON.parse(<<-JSON)
      {"type":"video","alt_text":"Walkthrough","title":{"type":"plain_text","text":"Walkthrough"},
       "thumbnail_url":"https://videos.example.test/thumb.jpg","video_url":"https://videos.example.test/embed/1"}
      JSON
  end

  it "keeps text below Slack's exclusive limits" do
    minimal_video(title: VideoUI.plain("界" * 199), description: VideoUI.plain("界" * 199), author_name: "界" * 49, block_id: "界" * 255).validate.should be_empty
    error = expect_raises(VideoUI::ValidationError) do
      minimal_video(title: VideoUI.plain("界" * 200), description: VideoUI.plain("界" * 200), author_name: "界" * 50, block_id: "界" * 256)
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"video.title.too_long", "title.text"}, {"video.description.too_long", "description.text"},
      {"video.author_name.too_long", "author_name"}, {"video.block_id.too_long", "block_id"},
    ]
  end

  it "requires alt text, a thumbnail, and HTTPS video and title links" do
    error = expect_raises(VideoUI::ValidationError) do
      minimal_video(alt_text: "", thumbnail_url: "", video_url: "http://videos.example.test/embed/1", title_url: "videos.example.test/watch/1")
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"video.alt_text.empty", "alt_text"}, {"video.thumbnail_url.empty", "thumbnail_url"},
      {"video.video_url.not_https", "video_url"}, {"video.title_url.not_https", "title_url"},
    ]
    minimal_video(video_url: "HTTPS://videos.example.test/embed/1", title_url: "https://videos.example.test/watch/1").validate.should be_empty
  end

  it "reports unparseable links as validation issues" do
    error = expect_raises(VideoUI::ValidationError) do
      minimal_video(alt_text: "", video_url: "https://videos.example.test:abc/embed/1", title_url: "https://videos.example.test:abc/watch/1")
    end
    error.issues.map { |issue| {issue.code, issue.path} }.should eq [
      {"video.alt_text.empty", "alt_text"}, {"video.video_url.not_https", "video_url"}, {"video.title_url.not_https", "title_url"},
    ]
  end

  it "is display content on Message, both modal kinds, and Home" do
    video = minimal_video(block_id: "clip")
    expected = JSON.parse({video}.to_json)
    surfaces = {
      VideoUI.message(fallback_text: "Walkthrough") { |builder| builder.add(video) },
      VideoUI::DisplayModal.new(title: VideoUI.plain("Watch"), blocks: {video}),
      VideoUI::FormModal.new(title: VideoUI.plain("Watch"), submit: VideoUI.plain("Done"), blocks: {video}),
      VideoUI::Home.new(blocks: [video]),
    }
    surfaces.each { |surface| JSON.parse(surface.to_json)["blocks"].should eq expected }
  end
end
