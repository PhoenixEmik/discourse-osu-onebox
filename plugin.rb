# frozen_string_literal: true

# name: discourse-osu-onebox
# about: Embed osu! user profiles and beatmaps inline in Discourse posts
# version: 1.0.0
# authors: PhoenixEmik
# url: https://github.com/PhoenixEmik/discourse-osu-onebox

module ::DiscourseOsuOnebox
end

register_asset "stylesheets/osu-onebox.scss"

require_relative "lib/discourse_osu_onebox/osu_auth"
require_relative "lib/discourse_osu_onebox/osu_user_onebox"
require_relative "lib/discourse_osu_onebox/osu_beatmap_onebox"
