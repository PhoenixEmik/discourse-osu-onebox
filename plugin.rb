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

# Extend the onebox sanitizer to allow <polyline> SVG elements (used for the
# rank history sparkline chart) and extra <svg> attributes.
after_initialize do
  require "onebox/sanitize_config"

  %i[ONEBOX DISCOURSE_ONEBOX].each do |const_name|
    next unless Onebox::SanitizeConfig.const_defined?(const_name)

    existing = Onebox::SanitizeConfig.const_get(const_name)

    patched_elements = (existing[:elements] + %w[polyline]).uniq
    patched_attributes =
      existing[:attributes].merge(
        "polyline" => %w[points fill stroke stroke-width stroke-linejoin stroke-linecap],
        "svg" => ((existing.dig(:attributes, "svg") || []) + %w[preserveAspectRatio xmlns]).uniq,
      )

    # Replace the last transformer (the SVG child-stripping one) so polyline is kept.
    # The ONEBOX config appends [a-link, iframe, svg-strip] after RELAXED's transformers;
    # the SVG-stripping transformer is always last.
    svg_transformer =
      lambda do |env|
        next if env[:node_name] != "svg"
        env[:node].traverse do |node|
          next if node.element? && %w[svg path polyline use].include?(node.name)
          node.remove
        end
      end

    existing_transformers = existing[:transformers] || []
    patched_transformers = existing_transformers[0..-2] + [svg_transformer]

    new_config =
      Sanitize::Config.freeze_config(
        existing.merge(
          elements: patched_elements,
          attributes: patched_attributes,
          transformers: patched_transformers,
        ),
      )

    Onebox::SanitizeConfig.send(:remove_const, const_name)
    Onebox::SanitizeConfig.const_set(const_name, new_config)
  end
end
