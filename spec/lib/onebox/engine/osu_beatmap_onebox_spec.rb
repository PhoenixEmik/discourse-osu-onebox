# frozen_string_literal: true

RSpec.describe Onebox::Engine::OsuBeatmapOnebox do
  def fixture(filename)
    file = "#{Rails.root}/plugins/discourse-osu-onebox/spec/fixtures/onebox/#{filename}.response"
    File.read(file)
  end

  let(:beatmap_link) { "https://osu.ppy.sh/beatmapsets/1697518#osu/3468147" }
  let(:beatmapset_api_url) { "https://osu.ppy.sh/api/v2/beatmapsets/1697518" }
  let(:token_url) { "https://osu.ppy.sh/oauth/token" }

  before do
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
    it "matches beatmapsets path" do
      expect(described_class.matches_path("/beatmapsets/1697518")).to eq(true)
    end

    it "does not match users path" do
      expect(described_class.matches_path("/users/7562902/osu")).to eq(false)
    end
  end

  describe "#to_html" do
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
