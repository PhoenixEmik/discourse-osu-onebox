# frozen_string_literal: true

require "onebox"
require_relative "osu_auth"

class Onebox::Engine::OsuUserOnebox
  include Onebox::Engine
  include DiscourseOsuOnebox::OsuAuth

  always_https
  matches_domain("osu.ppy.sh")

  def self.matches_path(path)
    path.match?(%r{^/users/\d+(/\w+)?$})
  end

  def to_html
    return nil unless osu_credentials_configured?

    user = fetch_user
    return nil unless user

    username = CGI.escapeHTML(user["username"].to_s)
    avatar_url = Onebox::Helpers.normalize_url_for_output(user["avatar_url"].to_s)
    cover_url = Onebox::Helpers.normalize_url_for_output(user["cover_url"].to_s)
    country = CGI.escapeHTML(user.dig("country", "name").to_s)
    country_code = CGI.escapeHTML(user["country_code"].to_s)
    profile_url = Onebox::Helpers.normalize_url_for_output(link)
    flag_url =
      Onebox::Helpers.normalize_url_for_output(
        "https://assets.ppy.sh/old-flags/#{country_code}.png",
      )

    stats = user["statistics"] || {}
    pp_value = stats["pp"].to_f.round(0).to_i
    global_rank = stats["global_rank"]
    country_rank = stats["country_rank"]
    accuracy = stats["hit_accuracy"].to_f.round(2)
    play_count = stats["play_count"].to_i
    ranked_score = stats["ranked_score"].to_i
    total_score = stats["total_score"].to_i
    total_hits = stats["total_hits"].to_i
    maximum_combo = stats["maximum_combo"].to_i
    replays_watched = stats["replays_watched_by_others"].to_i
    hits_per_play = play_count > 0 ? (total_hits.to_f / play_count).round : 0

    rank_str = global_rank ? "##{fmt(global_rank.to_i)}" : "Unranked"
    country_rank_str = country_rank ? "##{fmt(country_rank.to_i)}" : "-"

    stat_rows = [
      ["Ranked Score", fmt(ranked_score)],
      ["Hit Accuracy", "#{accuracy}%"],
      ["Play Count", fmt(play_count)],
      ["Total Score", fmt(total_score)],
      ["Total Hits", fmt(total_hits)],
      ["Hits Per Play", fmt(hits_per_play)],
      ["Maximum Combo", fmt(maximum_combo)],
      ["Replays Watched by Others", fmt(replays_watched)],
    ]

    rows_html =
      stat_rows
        .map do |label, value|
          "<div class=\"osu-user-stat-row\"><span class=\"osu-user-stat-label\">#{CGI.escapeHTML(label)}</span><span class=\"osu-user-stat-value\">#{CGI.escapeHTML(value.to_s)}</span></div>"
        end
        .join("\n        ")

    rank_history = user.dig("rankHistory", "data") || user.dig("rank_history", "data") || []
    chart_svg = rank_history_svg(rank_history)

    header_style = cover_url.present? ? " style=\"background-image: url('#{cover_url}');\"" : ""

    <<~HTML
      <aside class="onebox osu-user">
        <header class="source">
          <img src="https://osu.ppy.sh/favicon.ico" class="site-icon" width="16" height="16">
          <a href="https://osu.ppy.sh" target="_blank" rel="nofollow ugc noopener">osu!</a>
        </header>
        <div class="onebox-body">
          <div class="osu-user-header#{cover_url.present? ? " osu-user-header--cover" : ""}"#{header_style}>
            <img src="#{avatar_url}" class="osu-avatar" width="72" height="72" alt="#{username}">
            <div class="osu-user-identity">
              <h3 class="osu-user-name">
                <a href="#{profile_url}" target="_blank" rel="nofollow ugc noopener">#{username}</a>
              </h3>
              <p class="osu-user-country">
                <img src="#{flag_url}" width="28" height="18" alt="#{country_code}">#{country}
                <span class="osu-user-country-rank">#{CGI.escapeHTML(country_rank_str)}</span>
              </p>
              <p class="osu-user-pp">
                <span class="osu-user-pp-value">#{CGI.escapeHTML("#{fmt(pp_value)}pp")}</span>
                <span class="osu-user-global-rank">#{CGI.escapeHTML(rank_str)}</span>
              </p>
            </div>
            #{chart_svg.present? ? "<div class=\"osu-user-rank-chart\">#{chart_svg}</div>" : ""}
          </div>
          <div class="osu-user-body">
            <div class="osu-user-stats-table">
              #{rows_html}
            </div>
          </div>
        </div>
      </aside>
    HTML
  end

  private

  def fmt(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def rank_history_svg(data)
    return "" if data.length < 2

    w = 360
    h = 72
    pad = 3

    min_rank = data.min.to_f
    max_rank = data.max.to_f
    range = (max_rank - min_rank).nonzero? || 1.0

    points =
      data.each_with_index.map do |rank, i|
        x = pad + (i.to_f / (data.length - 1)) * (w - pad * 2)
        # lower rank number = better = higher on chart = smaller y in SVG
        y = pad + ((rank.to_f - min_rank) / range) * (h - pad * 2)
        "#{x.round(1)},#{y.round(1)}"
      end

    pts = CGI.escapeHTML(points.join(" "))

    "<svg viewBox=\"0 0 #{w} #{h}\" preserveAspectRatio=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><polyline points=\"#{pts}\" fill=\"none\" stroke=\"#ff79c6\" stroke-width=\"1.8\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/></svg>"
  end

  def url_match
    @url_match ||= @url.match(%r{/users/(\d+)(?:/(\w+))?})
  end

  def fetch_user
    user_id = url_match[1]
    mode = url_match[2] || "osu"
    response =
      Onebox::Helpers.fetch_response(
        "https://osu.ppy.sh/api/v2/users/#{user_id}/#{mode}",
        headers: osu_auth_header,
      )
    ::MultiJson.load(response)
  rescue StandardError
    nil
  end
end
