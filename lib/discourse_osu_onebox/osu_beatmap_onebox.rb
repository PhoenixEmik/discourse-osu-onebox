# frozen_string_literal: true

require "onebox"
require_relative "osu_auth"

class Onebox::Engine::OsuBeatmapOnebox
  include Onebox::Engine
  include DiscourseOsuOnebox::OsuAuth

  always_https
  matches_domain("osu.ppy.sh")

  def self.matches_path(path)
    path.match?(%r{^/beatmapsets/\d+$})
  end

  def to_html
    return nil unless osu_credentials_configured?

    beatmap = fetch_beatmap
    return nil unless beatmap

    beatmapset = beatmap["beatmapset"] || {}
    title = CGI.escapeHTML(beatmapset["title"].to_s)
    artist = CGI.escapeHTML(beatmapset["artist"].to_s)
    creator = CGI.escapeHTML(beatmapset["creator"].to_s)
    mapper_user_id = beatmapset["user_id"].to_i
    mapper_avatar_url =
      Onebox::Helpers.normalize_url_for_output(
        mapper_user_id > 0 ? "https://a.ppy.sh/#{mapper_user_id}" : "",
      )
    version = CGI.escapeHTML(beatmap["version"].to_s)
    status = beatmap["status"].to_s
    status_label = CGI.escapeHTML(status.capitalize)
    cover_url = Onebox::Helpers.normalize_url_for_output(beatmapset.dig("covers", "cover@2x").to_s)
    cover_url =
      Onebox::Helpers.normalize_url_for_output(
        beatmapset.dig("covers", "cover").to_s,
      ) if cover_url.blank?
    beatmap_url = Onebox::Helpers.normalize_url_for_output(link)

    stars = beatmap["difficulty_rating"].to_f.round(2)
    bpm = beatmap["bpm"].to_f.round(1)
    total_length = beatmap["total_length"].to_i
    length_str = format("%d:%02d", total_length / 60, total_length % 60)
    max_combo = beatmap["max_combo"].to_i
    cs = beatmap["cs"].to_f.round(1)
    ar = beatmap["ar"].to_f.round(1)
    od = beatmap["accuracy"].to_f.round(1)
    hp = beatmap["drain"].to_f.round(1)

    # bar widths are capped at 100%; stars capped at 10 for display
    bar_pct = ->(val, max = 10.0) { [(val / max * 100).round(1), 100].min }
    stars_pct = bar_pct.call(stars)

    bg_style = cover_url.present? ? "background-image:url('#{cover_url}');" : ""

    <<~HTML
      <aside class="onebox osu-beatmap">
        <header class="source">
          <img src="https://osu.ppy.sh/favicon.ico" class="site-icon" width="16" height="16">
          <a href="https://osu.ppy.sh" target="_blank" rel="nofollow ugc noopener">osu!</a>
        </header>
        <div class="onebox-body">
          <a href="#{beatmap_url}" target="_blank" rel="nofollow ugc noopener" class="osu-beatmap-card">
            <div class="osu-beatmap-cover" style="#{bg_style}">
              <div class="osu-beatmap-status-row">
                <span class="osu-beatmap-status osu-beatmap-status--#{CGI.escapeHTML(status)}">#{status_label}</span>
              </div>
            </div>
            <div class="osu-beatmap-info">
              <div class="osu-beatmap-meta-row">
                <div class="osu-beatmap-title-block">
                  <h3>#{artist} - #{title}</h3>
                  <p class="osu-beatmap-version">[#{version}]</p>
                  <p class="osu-beatmap-meta">
                    #{mapper_avatar_url.present? ? "<img src=\"#{mapper_avatar_url}\" class=\"osu-mapper-avatar\" width=\"25\" height=\"25\" alt=\"#{creator}\">" : ""}mapped by <span class="osu-beatmap-mapper">#{creator}</span>
                  </p>
                </div>
                <div class="osu-beatmap-stats-row">
                  <div class="osu-stat">
                    <span class="osu-stat-icon">⏱</span>
                    <span class="osu-stat-value">#{CGI.escapeHTML(length_str)}</span>
                    <span class="osu-stat-label">Length</span>
                  </div>
                  <div class="osu-stat">
                    <span class="osu-stat-icon">♩</span>
                    <span class="osu-stat-value">#{CGI.escapeHTML(bpm.to_s)}</span>
                    <span class="osu-stat-label">BPM</span>
                  </div>
                  #{max_combo > 0 ? "<div class=\"osu-stat\"><span class=\"osu-stat-icon\">⊕</span><span class=\"osu-stat-value\">#{CGI.escapeHTML(max_combo.to_s)}</span><span class=\"osu-stat-label\">Max Combo</span></div>" : ""}
                  <div class="osu-stat">
                    <span class="osu-stat-icon">★</span>
                    <span class="osu-stat-value">#{CGI.escapeHTML(stars.to_s)}</span>
                    <span class="osu-stat-label">Stars</span>
                  </div>
                </div>
              </div>
              <div class="osu-beatmap-difficulty">
                <div class="osu-diff-row">
                  <span class="osu-diff-label">Circle Size</span>
                  <div class="osu-diff-bar"><div class="osu-diff-fill" style="width:#{bar_pct.call(cs)}%"></div></div>
                  <span class="osu-diff-value">#{CGI.escapeHTML(cs.to_s)}</span>
                </div>
                <div class="osu-diff-row">
                  <span class="osu-diff-label">HP Drain</span>
                  <div class="osu-diff-bar"><div class="osu-diff-fill" style="width:#{bar_pct.call(hp)}%"></div></div>
                  <span class="osu-diff-value">#{CGI.escapeHTML(hp.to_s)}</span>
                </div>
                <div class="osu-diff-row">
                  <span class="osu-diff-label">Accuracy</span>
                  <div class="osu-diff-bar"><div class="osu-diff-fill" style="width:#{bar_pct.call(od)}%"></div></div>
                  <span class="osu-diff-value">#{CGI.escapeHTML(od.to_s)}</span>
                </div>
                <div class="osu-diff-row">
                  <span class="osu-diff-label">Approach Rate</span>
                  <div class="osu-diff-bar"><div class="osu-diff-fill" style="width:#{bar_pct.call(ar)}%"></div></div>
                  <span class="osu-diff-value">#{CGI.escapeHTML(ar.to_s)}</span>
                </div>
                <div class="osu-diff-row osu-diff-row--stars">
                  <span class="osu-diff-label">Star Rating</span>
                  <div class="osu-diff-bar"><div class="osu-diff-fill" style="width:#{stars_pct}%"></div></div>
                  <span class="osu-diff-value">#{CGI.escapeHTML(stars.to_s)}</span>
                </div>
              </div>
            </div>
          </a>
        </div>
      </aside>
    HTML
  end

  private

  def beatmap_id
    uri = URI.parse(@url)
    uri.fragment&.match(%r{/(\d+)})&.[](1)
  end

  def beatmapset_id
    @url.match(%r{/beatmapsets/(\d+)})[1]
  end

  def fetch_beatmap
    fetch_beatmapset_and_pick(beatmapset_id, beatmap_id)
  end

  def fetch_beatmapset_and_pick(set_id, pick_id = nil)
    response =
      Onebox::Helpers.fetch_response(
        "https://osu.ppy.sh/api/v2/beatmapsets/#{set_id}",
        headers: osu_auth_header,
      )
    data = ::MultiJson.load(response)
    beatmaps = data["beatmaps"] || []
    diff = (beatmaps.find { |b| b["id"].to_s == pick_id.to_s } if pick_id)
    diff ||= beatmaps.max_by { |b| b["difficulty_rating"].to_f }
    return nil unless diff

    diff["beatmapset"] = data.except("beatmaps")
    diff
  rescue StandardError
    nil
  end
end
