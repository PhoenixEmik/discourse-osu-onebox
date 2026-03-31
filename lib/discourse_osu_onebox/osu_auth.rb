# frozen_string_literal: true

module DiscourseOsuOnebox
  module OsuAuth
    OSU_TOKEN_URL = "https://osu.ppy.sh/oauth/token"
    OSU_TOKEN_CACHE_KEY = "osu_onebox_access_token"

    def osu_auth_header
      return {} unless osu_credentials_configured?

      token = fetch_osu_access_token
      return {} if token.blank?

      { "Authorization" => "Bearer #{token}" }
    end

    def osu_credentials_configured?
      SiteSetting.osu_onebox_client_id.present? && SiteSetting.osu_onebox_client_secret.present?
    end

    private

    def fetch_osu_access_token
      Discourse
        .cache
        .fetch(OSU_TOKEN_CACHE_KEY, expires_in: 23.hours) do
          response =
            Excon.post(
              OSU_TOKEN_URL,
              body:
                URI.encode_www_form(
                  client_id: SiteSetting.osu_onebox_client_id,
                  client_secret: SiteSetting.osu_onebox_client_secret,
                  grant_type: "client_credentials",
                  scope: "public",
                ),
              headers: {
                "Content-Type" => "application/x-www-form-urlencoded",
                "User-Agent" => Onebox::Helpers.user_agent,
              },
            )

          ::MultiJson.load(response.body)["access_token"] if response.status == 200
        end
    end
  end
end
