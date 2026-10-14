# frozen_string_literal: true

RSpec.describe Onebox::Engine::OsuBeatmapOnebox do
  def fixture(filename)
    file = File.join(DiscourseOsuOnebox::PLUGIN_ROOT, "spec/fixtures/onebox/#{filename}.response")
    File.read(file)
  end

  let(:beatmap_link) { "https://osu.ppy.sh/beatmapsets/1697518#osu/3468147" }
  let(:beatmapset_api_url) { "https://osu.ppy.sh/api/v2/beatmapsets/1697518" }
  let(:token_url) { "https://osu.ppy.sh/oauth/token" }

  before do
    allow(Discourse).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    SiteSetting.osu_onebox_client_id = "client123"
    SiteSetting.osu_onebox_client_secret = "secret456"
    stub_request(:post, token_url).to_return(
      status: 200,
      body: '{"access_token":"test_token","token_type":"Bearer","expires_in":86400}',
    )
    stub_request(:get, beatmapset_api_url).to_return(status: 200, body: fixture("osu_beatmap"))
  end

  let(:html) { described_class.new(beatmap_link).to_html }

  describe ".matches_path" do
    it "matches trailing slashes" do
      expect(described_class.matches_path("/beatmapsets/1697518/")).to eq(true)
    end

    it "rejects extra segments and newlines" do
      ["/beatmapsets/1697518/extra", "/beatmapsets/1697518\n"].each do |path|
        expect(described_class.matches_path(path)).to eq(false)
      end
    end

    it "matches beatmapsets path" do
      expect(described_class.matches_path("/beatmapsets/1697518")).to eq(true)
    end

    it "does not match users path" do
      expect(described_class.matches_path("/users/7562902/osu")).to eq(false)
    end
  end

  describe "#to_html" do
    context "with multiple difficulties and modes" do
      before do
        data = MultiJson.load(fixture("osu_beatmap"))
        data["beatmaps"] << data["beatmaps"].first.merge(
          "id" => 2,
          "difficulty_rating" => 8.0,
          "version" => "Harder osu difficulty",
        )
        data["beatmaps"] << data["beatmaps"].first.merge(
          "id" => 3,
          "mode" => "mania",
          "difficulty_rating" => 9.0,
          "version" => "Mania difficulty",
        )
        stub_request(:get, beatmapset_api_url).to_return(status: 200, body: MultiJson.dump(data))
      end

      it "selects the requested difficulty even when another has more stars" do
        expect(html).to include("[Extra]")
        expect(html).not_to include("Harder osu difficulty", "Mania difficulty")
      end

      it "selects the hardest difficulty in the requested mode" do
        result = described_class.new("https://osu.ppy.sh/beatmapsets/1697518#osu").to_html
        expect(result).to include("Harder osu difficulty")
        expect(result).not_to include("Mania difficulty")
      end

      it "selects the hardest difficulty when no fragment is given" do
        result = described_class.new("https://osu.ppy.sh/beatmapsets/1697518/").to_html
        expect(result).to include("Mania difficulty")
      end

      it "returns nil for an unavailable difficulty or mode" do
        %w[osu/999 osu/3 taiko].each do |fragment|
          expect(
            described_class.new("https://osu.ppy.sh/beatmapsets/1697518##{fragment}").to_html,
          ).to be_nil
        end
      end
    end

    it "does not call the API for an invalid fragment" do
      expect(
        described_class.new("https://osu.ppy.sh/beatmapsets/1697518#osu/3468147/extra").to_html,
      ).to be_nil
      expect(a_request(:get, beatmapset_api_url)).not_to have_been_made
    end

    it "does not call the API when authentication fails" do
      stub_request(:post, token_url).to_return(status: 401)
      expect(html).to be_nil
      expect(a_request(:get, beatmapset_api_url)).not_to have_been_made
    end

    it "returns nil on an API error" do
      stub_request(:get, beatmapset_api_url).to_return(status: 404)
      expect(html).to be_nil
    end

    it "returns nil for malformed JSON and unexpected responses" do
      ["not json", "null", "[]", '{"beatmaps":[]}', '{"beatmaps":[null]}'].each do |body|
        stub_request(:get, beatmapset_api_url).to_return(status: 200, body: body)
        expect(described_class.new(beatmap_link).to_html).to be_nil
      end
    end

    it "clamps difficulty bar widths to valid percentages" do
      data = MultiJson.load(fixture("osu_beatmap"))
      data["beatmaps"].first.merge!("cs" => -1, "ar" => 12)
      stub_request(:get, beatmapset_api_url).to_return(status: 200, body: MultiJson.dump(data))
      bars = Nokogiri::HTML5.fragment(html).css(".osu-diff-fill")
      expect(bars[0]["style"]).to eq("width:0%")
      expect(bars[3]["style"]).to eq("width:100%")
    end

    it "includes the song title" do
      expect(html).to include("TOKONOMA Strider")
    end

    it "includes the artist" do
      expect(html).to include("Yooh")
    end

    it "includes the mapper" do
      expect(html).to include("Nathan")
    end

    it "includes the difficulty name" do
      expect(html).to include("Extra")
    end

    it "includes the star rating" do
      expect(html).to include("6.23")
    end

    it "includes the BPM" do
      expect(html).to include("180")
    end

    it "includes the length" do
      expect(html).to include("3:30")
    end

    it "includes difficulty bar labels" do
      expect(html).to include("Circle Size")
      expect(html).to include("HP Drain")
      expect(html).to include("Accuracy")
      expect(html).to include("Approach Rate")
      expect(html).to include("Star Rating")
    end

    it "includes difficulty bar values" do
      expect(html).to include(">4.0<")
      expect(html).to include(">9.2<")
    end

    it "includes max combo" do
      expect(html).to include("1234")
    end

    it "includes the ranked status" do
      expect(html).to include("Ranked")
    end

    it "includes the cover image" do
      expect(html).to include("https://assets.ppy.sh/beatmaps/1697518/covers/cover")
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
end
