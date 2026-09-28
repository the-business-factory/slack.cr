require "../spec_helper"

module DataVisualizationBlockSpec
  alias UI = Slack::UI
  alias DV = UI::DataVisualization

  def self.series(name : String, categories : Enumerable(String), value : Int32 = 1) : DV::DataSeries
    DV::DataSeries.new(name, categories.map { |category| DV::DataPoint.new(category, value) })
  end

  def self.pie : DV::PieChart
    DV::PieChart.new({DV::Segment.new("Open", 1)})
  end

  def self.codes(error : UI::ValidationError) : Array(Tuple(String, String))
    error.issues.map { |issue| {issue.code, issue.path} }
  end

  describe UI::Blocks::DataVisualization do
    it "serializes pie and bar charts in a message" do
      bar = DV::BarChart.new(
        series: [
          DV::DataSeries.new("Median", [DV::DataPoint.new("Mon", 12), DV::DataPoint.new("Tue", -3.5)]),
          DV::DataSeries.new("P90", {DV::DataPoint.new("Tue", 40), DV::DataPoint.new("Mon", 31)}),
        ],
        axis_config: DV::AxisConfig.new({"Mon", "Tue"}, x_label: "Day", y_label: "Minutes")
      )
      message = UI.message(fallback_text: "Weekly support report") do |builder|
        builder.data_visualization("Tickets by channel", block_id: "tickets.by_channel", chart: DV::PieChart.new([
          DV::Segment.new("Email", 45), DV::Segment.new("Chat", 28.5), DV::Segment.new("Phone", 9),
        ]))
        builder.add(UI::Blocks::DataVisualization.new(title: "Response time by day", chart: bar))
      end

      JSON.parse(message.to_json).should eq JSON.parse(File.read("spec/fixtures/block_kit/data_visualization_message.json"))
    end

    it "places area and line charts on Home without optional axis labels" do
      axis = DV::AxisConfig.new(["Q1", "Q2"])
      home = UI.home do |builder|
        builder.data_visualization("Signups", DV::AreaChart.new({series("Free", {"Q1", "Q2"}, 3)}, axis))
        builder.data_visualization("Churn", DV::LineChart.new({series("Paid", {"Q2", "Q1"}, 2)}, axis), block_id: "churn")
      end

      JSON.parse(home.to_json)["blocks"].should eq JSON.parse(<<-JSON)
        [{"type":"data_visualization","title":"Signups","chart":{"type":"area",
           "series":[{"name":"Free","data":[{"label":"Q1","value":3},{"label":"Q2","value":3}]}],
           "axis_config":{"categories":["Q1","Q2"]}}},
         {"type":"data_visualization","block_id":"churn","title":"Churn","chart":{"type":"line",
           "series":[{"name":"Paid","data":[{"label":"Q2","value":2},{"label":"Q1","value":2}]}],
           "axis_config":{"categories":["Q1","Q2"]}}}]
        JSON
    end

    it "owns copies of segments, series, data points, and categories" do
      segments = [DV::Segment.new("A", 1)]
      categories = ["Mon"]
      points = [DV::DataPoint.new("Mon", 1)]
      data_series = DV::DataSeries.new("S", points)
      all_series = [data_series]
      axis = DV::AxisConfig.new(categories)
      pie_chart = DV::PieChart.new(segments)
      line = DV::LineChart.new(all_series, axis)
      segments << DV::Segment.new("B", 2)
      categories << "Tue"
      points << DV::DataPoint.new("Tue", 2)
      all_series << series("T", {"Mon"})
      pie_chart.segments << DV::Segment.new("C", 3)
      axis.categories << "Wed"
      data_series.data << DV::DataPoint.new("Wed", 3)
      line.series.clear

      JSON.parse(pie_chart.to_json).should eq JSON.parse(%({"type":"pie","segments":[{"label":"A","value":1}]}))
      JSON.parse(line.to_json).should eq JSON.parse(<<-JSON)
        {"type":"line","series":[{"name":"S","data":[{"label":"Mon","value":1}]}],"axis_config":{"categories":["Mon"]}}
        JSON
    end

    it "accepts Slack's documented maximums" do
      categories = Array.new(20, &.to_s.rjust(20, '界'))
      all_series = Array.new(12) { |index| series(index.to_s.rjust(20, 's'), categories) }
      bar = DV::BarChart.new(all_series, DV::AxisConfig.new(categories, x_label: "x" * 50, y_label: "y" * 50))
      pie_chart = DV::PieChart.new(Array.new(12) { |index| DV::Segment.new(index.to_s.rjust(20, 'p'), 0.001) })

      UI::Blocks::DataVisualization.new("t" * 50, bar, block_id: "界" * 255).chart.should eq bar
      UI::Blocks::DataVisualization.new("Pie", pie_chart).title.should eq "Pie"
    end

    it "rejects titles, labels, and collections beyond Slack's limits" do
      error = expect_raises(UI::ValidationError) { DV::PieChart.new(Array.new(13) { |index| DV::Segment.new(index.to_s, 1) }) }
      codes(error).should eq [{"pie.segments.too_many", "segments"}]
      expect_raises(UI::ValidationError, /20 characters/) { DV::Segment.new("s" * 21, 1) }
      expect_raises(UI::ValidationError, /20 characters/) { DV::DataPoint.new("p" * 21, 1) }

      error = expect_raises(UI::ValidationError) { DV::DataSeries.new("n" * 21, Array.new(21) { |index| DV::DataPoint.new(index.to_s, 1) }) }
      codes(error).should eq [{"data_series.name.too_long", "name"}, {"data_series.data.too_many", "data"}]

      error = expect_raises(UI::ValidationError) do
        DV::AxisConfig.new(Array.new(21) { |index| index == 2 ? "c" * 21 : index.to_s }, x_label: "x" * 51, y_label: "y" * 51)
      end
      codes(error).should eq [
        {"axis_config.categories.too_many", "categories"},
        {"axis_config.category.too_long", "categories[2]"},
        {"axis_config.x_label.too_long", "x_label"},
        {"axis_config.y_label.too_long", "y_label"},
      ]

      error = expect_raises(UI::ValidationError) do
        DV::AreaChart.new(Array.new(13) { |index| series(index.to_s, {"Mon"}) }, DV::AxisConfig.new({"Mon"}))
      end
      codes(error).should eq [{"area.series.too_many", "series"}]

      error = expect_raises(UI::ValidationError) { UI::Blocks::DataVisualization.new("t" * 51, pie, block_id: "b" * 256) }
      codes(error).should eq [{"data_visualization.title.too_long", "title"}, {"data_visualization.block_id.too_long", "block_id"}]
    end

    it "requires unique series names and exactly one point for each category" do
      axis = DV::AxisConfig.new({"Mon", "Tue", "Wed"})
      error = expect_raises(UI::ValidationError) do
        DV::BarChart.new(axis_config: axis, series: {
          series("Median", {"Mon", "Tue", "Wed"}),
          series("Median", {"Mon", "Tue", "Wed"}),
          series("Gaps", {"Mon", "Mon", "Thu"}),
        })
      end
      codes(error).should eq [
        {"bar.series.name.duplicate", "series[1].name"},
        {"bar.series.data.duplicate_category", "series[2].data[1].label"},
        {"bar.series.data.unknown_category", "series[2].data[2].label"},
        {"bar.series.data.missing_category", "series[2].data"},
      ]
      error.issues.last.message.should contain %("Tue", "Wed")
    end

    it "rejects empty collections and strings, duplicate labels, and invalid numbers as library policy" do
      expect_raises(UI::ValidationError, /at least one segment/) { DV::PieChart.new([] of DV::Segment) }
      expect_raises(UI::ValidationError, /at least one data point/) { DV::DataSeries.new("S", [] of DV::DataPoint) }
      expect_raises(UI::ValidationError, /at least one category/) { DV::AxisConfig.new([] of String) }
      expect_raises(UI::ValidationError, /at least one series/) { DV::LineChart.new([] of DV::DataSeries, DV::AxisConfig.new({"Mon"})) }
      expect_raises(UI::ValidationError, /must not be empty/) { UI::Blocks::DataVisualization.new("", pie) }
      expect_raises(UI::ValidationError, /must not be empty/) { DV::DataSeries.new("", {DV::DataPoint.new("Mon", 1)}) }
      expect_raises(UI::ValidationError, /must not be empty/) { DV::DataPoint.new("", 1) }

      codes(expect_raises(UI::ValidationError) { DV::Segment.new("", 0) }).should eq [
        {"segment.label.empty", "label"}, {"segment.value.not_positive", "value"},
      ]
      codes(expect_raises(UI::ValidationError) { DV::Segment.new("Loss", -0.5) }).should eq [{"segment.value.not_positive", "value"}]
      codes(expect_raises(UI::ValidationError) { DV::Segment.new("NaN", Float64::NAN) }).should eq [{"segment.value.not_finite", "value"}]
      codes(expect_raises(UI::ValidationError) { DV::Segment.new("Inf", Float64::INFINITY) }).should eq [{"segment.value.not_finite", "value"}]
      codes(expect_raises(UI::ValidationError) { DV::DataPoint.new("Mon", -Float64::INFINITY) }).should eq [{"data_point.value.not_finite", "value"}]

      codes(expect_raises(UI::ValidationError) { DV::AxisConfig.new({"Mon", "", "Mon"}) }).should eq [
        {"axis_config.category.empty", "categories[1]"}, {"axis_config.category.duplicate", "categories[2]"},
      ]
      codes(expect_raises(UI::ValidationError) { DV::PieChart.new({DV::Segment.new("A", 1), DV::Segment.new("A", 2)}) }).should eq [
        {"pie.segment.label.duplicate", "segments[1].label"},
      ]
    end

    it "limits a message, but not Home, to two data visualization blocks" do
      charts = Array.new(3) { |index| UI::Blocks::DataVisualization.new("Chart #{index}", pie) }
      error = expect_raises(UI::ValidationError) { UI::Message.new(fallback_text: "Charts", blocks: charts) }
      codes(error).should eq [{"message.data_visualization.too_many", "blocks"}]
      UI::Message.new(fallback_text: "Charts", blocks: charts.first(2)).blocks.size.should eq 2
      UI::Home.new(blocks: charts).blocks.size.should eq 3
    end
  end
end
