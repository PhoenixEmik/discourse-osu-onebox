# frozen_string_literal: true

RSpec.describe Onebox::Engine::OsuUserOnebox do
  def fixture(filename)
    file = File.join(DiscourseOsuOnebox::PLUGIN_ROOT, "spec/fixtures/onebox/#{filename}.response")
    File.read(file)
  end

  let(:profile_link) { "https://osu.ppy.sh/users/7562902/osu" }
  let(:api_url) { "https://osu.ppy.sh/api/v2/users/7562902/osu" }
  let(:token_url) { "https://osu.ppy.sh/oauth/token" }

  before do
    allow(Discourse).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    SiteSetting.osu_onebox_client_id = "client123"
    SiteSetting.osu_onebox_client_secret = "secret456"
    stub_request(:post, token_url).to_return(
      status: 200,
      body: '{"access_token":"test_token","token_type":"Bearer","expires_in":86400}',
    )
    stub_request(:get, api_url).to_return(status: 200, body: fixture("osu_user"))
  end

  let(:html) { described_class.new(profile_link).to_html }

  describe ".matches_path" do
    it "matches all supported modes and trailing slashes" do
      %w[osu taiko fruits mania].each do |mode|
        expect(described_class.matches_path("/users/7562902/#{mode}/")).to eq(true)
      end
      expect(described_class.matches_path("/users/7562902/")).to eq(true)
    end

    it "rejects unsupported modes, extra segments, and newlines" do
      ["/users/7562902/unknown", "/users/7562902/osu/extra", "/users/7562902\n"].each do |path|
        expect(described_class.matches_path(path)).to eq(false)
      end
    end

    it "matches user path with mode" do
      expect(described_class.matches_path("/users/7562902/osu")).to eq(true)
    end

    it "matches user path without mode" do
      expect(described_class.matches_path("/users/7562902")).to eq(true)
    end

    it "does not match beatmapsets path" do
      expect(described_class.matches_path("/beatmapsets/1697518")).to eq(false)
    end
  end

  describe "#to_html" do
    it "requests the chosen mode with authorization" do
      stub_request(:get, "https://osu.ppy.sh/api/v2/users/7562902/mania").with(
        headers: {
          "Authorization" => "Bearer test_token",
        },
      ).to_return(status: 200, body: fixture("osu_user"))
      result = described_class.new("https://osu.ppy.sh/users/7562902/mania/").to_html
      expect(result).to include("/rankings/mania/performance?country=JP")
    end

    it "uses osu mode when the URL has no mode" do
      expect(described_class.new("https://osu.ppy.sh/users/7562902").to_html).to include("5,235pp")
      expect(a_request(:get, api_url)).to have_been_made.once
    end

    it "uses the current cover field before the legacy cover_url" do
      data = MultiJson.load(fixture("osu_user"))
      data["cover"] = { "url" => "https://assets.ppy.sh/current-cover.jpg" }
      stub_request(:get, api_url).to_return(status: 200, body: MultiJson.dump(data))
      expect(html).to include("https://assets.ppy.sh/current-cover.jpg")
      expect(html).not_to include(data["cover_url"])
    end

    it "escapes user-provided text" do
      data = MultiJson.load(fixture("osu_user"))
      data["username"] = '<script>alert("x")</script>'
      stub_request(:get, api_url).to_return(status: 200, body: MultiJson.dump(data))
      expect(html).to include("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")
      expect(Nokogiri::HTML5.fragment(html).css("script")).to be_empty
    end

    it "preserves the chart through the standard onebox sanitizers" do
      %i[ONEBOX DISCOURSE_ONEBOX].each do |name|
        sanitized = Sanitize.fragment(html, Onebox::SanitizeConfig.const_get(name))
        chart = Nokogiri::HTML5.fragment(sanitized).at_css(".osu-user-rank-chart svg path")
        expect(chart).to be_present
        expect(chart["d"]).to start_with("M")
        expect(chart["d"]).to include("L")
      end
    end

    it "renders an unranked user without statistics or history" do
      data = MultiJson.load(fixture("osu_user"))
      data["statistics"] = nil
      data["rankHistory"] = nil
      stub_request(:get, api_url).to_return(status: 200, body: MultiJson.dump(data))
      expect(html).to include("Unranked", "0pp")
      expect(html).not_to include("osu-user-rank-chart")
    end

    it "does not call the API when authentication fails" do
      stub_request(:post, token_url).to_return(status: 401)
      expect(html).to be_nil
      expect(a_request(:get, api_url)).not_to have_been_made
    end

    it "returns nil on an API error" do
      stub_request(:get, api_url).to_return(status: 404)
      expect(html).to be_nil
    end

    it "returns nil for malformed JSON and unexpected responses" do
      ["not json", "null", "[]", '{"error":"unavailable"}'].each do |body|
        stub_request(:get, api_url).to_return(status: 200, body: body)
        expect(described_class.new(profile_link).to_html).to be_nil
      end
    end

    it "includes the username" do
      expect(html).to include("Shirasaka Koume")
    end

    it "includes the avatar" do
      expect(html).to include("https://a.ppy.sh/7562902")
    end

    it "includes the pp value formatted" do
      expect(html).to include("5,235pp")
    end

    it "includes the global rank formatted" do
      expect(html).to include("#12,345")
    end

    it "includes the country rank formatted" do
      expect(html).to include("#234")
    end

    it "includes the country" do
      expect(html).to include("Japan")
    end

    it "includes hit accuracy" do
      expect(html).to include("98.23%")
    end

    it "includes play count formatted" do
      expect(html).to include("45,678")
    end

    it "includes ranked score formatted" do
      expect(html).to include("141,452,766,261")
    end

    it "includes total score formatted" do
      expect(html).to include("935,631,841,277")
    end

    it "includes total hits formatted" do
      expect(html).to include("66,834,294")
    end

    it "includes hits per play" do
      # 66834294 / 45678 ≈ 1463
      expect(html).to include("Hits Per Play")
    end

    it "includes maximum combo formatted" do
      expect(html).to include("8,749")
    end

    it "includes replays watched formatted" do
      expect(html).to include("4,550,510")
    end

    it "links to the profile" do
      expect(html).to include("https://osu.ppy.sh/users/7562902/osu")
    end

    context "when credentials are not configured" do
      before do
        SiteSetting.osu_onebox_client_id = ""
        SiteSetting.osu_onebox_client_secret = ""
      end

      it "returns nil" do
        expect(html).to be_nil
      end
    end
  end

  describe "rank history" do
    let(:engine) { described_class.new(profile_link) }

    it "puts better ranks higher on the chart" do
      svg = engine.send(:rank_history_svg, [100, 50])
      expect(svg).to include('d="M3.0,69.0 L177.0,3.0"')
    end

    it "handles a constant rank" do
      svg = engine.send(:rank_history_svg, [100, 100])
      expect(svg).to include('d="M3.0,3.0 L177.0,3.0"')
    end

    it "leaves gaps for days with missing or unranked values" do
      svg = engine.send(:rank_history_svg, [100, 90, nil, 0, "bad", 60, 50])
      path = Nokogiri::HTML5.fragment(svg).at_css("path")["d"]
      expect(path.scan("M").length).to eq(2)
      expect(path.scan("L").length).to eq(2)
    end

    it "omits charts with fewer than two valid ranks" do
      [nil, {}, [], [100], [nil, 0], [100, Float::NAN, Float::INFINITY]].each do |data|
        expect(engine.send(:rank_history_svg, data)).to eq("")
      end
    end
  end
end
