# frozen_string_literal: true

require "active_support/testing/time_helpers"

RSpec.describe DiscourseOsuOnebox::OsuAuth do
  include ActiveSupport::Testing::TimeHelpers

  let(:auth) { Class.new { include DiscourseOsuOnebox::OsuAuth }.new }
  let(:token_url) { described_class::OSU_TOKEN_URL }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:token_response) { { access_token: "test_token", token_type: "Bearer", expires_in: 3600 } }

  before do
    SiteSetting.osu_onebox_client_id = "client123"
    SiteSetting.osu_onebox_client_secret = "secret456"
    allow(Discourse).to receive(:cache).and_return(cache)
    stub_request(:post, token_url).to_return(status: 200, body: MultiJson.dump(token_response))
  end

  it "requests a public client-credentials token" do
    expect(auth.osu_auth_header).to eq("Authorization" => "Bearer test_token")
    expect(
      a_request(:post, token_url).with(
        body: {
          client_id: "client123",
          client_secret: "secret456",
          grant_type: "client_credentials",
          scope: "public",
        },
        headers: {
          "Accept" => "application/json",
        },
      ),
    ).to have_been_made.once
  end

  it "reuses a cached token" do
    2.times { expect(auth.osu_auth_header).to eq("Authorization" => "Bearer test_token") }
    expect(a_request(:post, token_url)).to have_been_made.once
  end

  it "caches for the reported lifetime with a safety margin" do
    freeze_time do
      auth.osu_auth_header
      travel 3539.seconds
      auth.osu_auth_header
      expect(a_request(:post, token_url)).to have_been_made.once

      travel 2.seconds
      expect(auth.osu_auth_header).to eq("Authorization" => "Bearer test_token")
      expect(a_request(:post, token_url)).to have_been_made.twice
    end
  end

  it "handles short-lived tokens" do
    token_response[:expires_in] = 30
    stub_request(:post, token_url).to_return(status: 200, body: MultiJson.dump(token_response))
    freeze_time do
      auth.osu_auth_header
      travel 26.seconds
      auth.osu_auth_header
      expect(a_request(:post, token_url)).to have_been_made.once

      travel 2.seconds
      expect(auth.osu_auth_header).to eq("Authorization" => "Bearer test_token")
      expect(a_request(:post, token_url)).to have_been_made.twice
    end
  end

  it "fetches a new token after either credential changes" do
    auth.osu_auth_header
    SiteSetting.osu_onebox_client_secret = "new_secret"
    auth.osu_auth_header
    SiteSetting.osu_onebox_client_id = "new_client"
    auth.osu_auth_header
    expect(a_request(:post, token_url)).to have_been_made.times(3)
  end

  it "does not cache a failed token request" do
    stub_request(:post, token_url).to_return(status: 401)
    expect(auth.osu_auth_header).to eq({})
    stub_request(:post, token_url).to_return(status: 200, body: MultiJson.dump(token_response))
    expect(auth.osu_auth_header).to eq("Authorization" => "Bearer test_token")
    expect(a_request(:post, token_url)).to have_been_made.twice
  end

  it "returns an empty header for invalid token responses" do
    [
      "not json",
      "null",
      "[]",
      "{}",
      '{"access_token":123,"expires_in":3600}',
      '{"access_token":"token","expires_in":0}',
      '{"access_token":"token","expires_in":{}}',
    ].each do |body|
      stub_request(:post, token_url).to_return(status: 200, body: body)
      expect(auth.osu_auth_header).to eq({})
    end
  end

  it "returns an empty header on a timeout" do
    stub_request(:post, token_url).to_timeout
    expect(auth.osu_auth_header).to eq({})
  end

  it "does not request a token when either credential is missing" do
    SiteSetting.osu_onebox_client_secret = ""
    expect(auth.osu_auth_header).to eq({})
    SiteSetting.osu_onebox_client_secret = "secret456"
    SiteSetting.osu_onebox_client_id = ""
    expect(auth.osu_auth_header).to eq({})
    expect(a_request(:post, token_url)).not_to have_been_made
  end
end
