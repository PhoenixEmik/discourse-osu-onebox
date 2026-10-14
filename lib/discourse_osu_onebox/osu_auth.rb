# frozen_string_literal: true

require "digest"
require "excon"

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
      client_id = SiteSetting.osu_onebox_client_id
      client_secret = SiteSetting.osu_onebox_client_secret
      # Rotating either credential must invalidate the cached token without putting
      # the client secret in a cache key.
      fingerprint = Digest::SHA256.hexdigest(::MultiJson.dump([client_id, client_secret]))
      cache_key = "#{OSU_TOKEN_CACHE_KEY}:#{fingerprint}"
      token = Discourse.cache.read(cache_key)
      return token if token.present?

      response =
        Excon.post(
          OSU_TOKEN_URL,
          body:
            URI.encode_www_form(
              client_id: client_id,
              client_secret: client_secret,
              grant_type: "client_credentials",
              scope: "public",
            ),
          headers: {
            "Accept" => "application/json",
            "Content-Type" => "application/x-www-form-urlencoded",
            "User-Agent" => Onebox::Helpers.user_agent,
          },
          connect_timeout: Onebox.options.connect_timeout,
          read_timeout: Onebox.options.timeout,
          write_timeout: Onebox.options.timeout,
        )
      return nil unless response.status == 200

      data = ::MultiJson.load(response.body)
      return nil unless data.is_a?(Hash)

      token = data["access_token"]
      expires_in = data["expires_in"]
      return nil unless token.is_a?(String) && token.present?
      return nil unless expires_in.is_a?(Integer) && expires_in > 0

      # Leave a margin for the request and clock skew, including short-lived tokens.
      expires_in -= [60, expires_in / 10].min
      Discourse.cache.write(cache_key, token, expires_in: expires_in)
      token
    rescue Excon::Error, MultiJson::ParseError
      nil
    end
  end
end
