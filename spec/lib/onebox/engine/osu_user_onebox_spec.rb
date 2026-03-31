# frozen_string_literal: true

RSpec.describe Onebox::Engine::OsuUserOnebox do
  def fixture(filename)
    file = "#{Rails.root}/plugins/discourse-osu-onebox/spec/fixtures/onebox/#{filename}.response"
    File.read(file)
  end

  let(:profile_link) { "https://osu.ppy.sh/users/7562902/osu" }
  let(:api_url) { "https://osu.ppy.sh/api/v2/users/7562902/osu" }
  let(:token_url) { "https://osu.ppy.sh/oauth/token" }

  before do
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
end
