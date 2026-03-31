# discourse-osu-onebox

A Discourse plugin that renders rich onebox cards for [osu!](https://osu.ppy.sh) user profiles and beatmaps when their URLs are pasted into posts.

## Features

### User profile card
- Cover image as header background with overlay
- Avatar, username, country flag, country rank
- Performance points (pp) and global rank
- 90-day rank history sparkline chart
- Stats table: ranked score, accuracy, play count, total score, total hits, max combo, replays watched

### Beatmap card
- Beatmap cover image
- Song title, difficulty name, status badge (ranked/loved/approved/etc.)
- Mapper name and avatar
- Stats: length, BPM, max combo, star rating
- Difficulty bars: circle size, HP drain, accuracy, approach rate, star rating

## Examples

```
https://osu.ppy.sh/users/7562902/osu
https://osu.ppy.sh/beatmapsets/1697518#osu/3468147
```

## Installation

1. In your `app.yml`, add the plugin under the `hooks > after_code` section:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/PhoenixEmik/discourse-osu-onebox.git
```

2. Rebuild your Discourse container:

```bash
./launcher rebuild app
```

## Configuration

This plugin requires an osu! API v2 OAuth client. Create one at <https://osu.ppy.sh/home/account/edit#new-oauth-application>.

In your Discourse admin panel, go to **Settings → Plugins** and set:

| Setting | Description |
|---|---|
| `osu_client_id` | Your osu! OAuth application client ID |
| `osu_client_secret` | Your osu! OAuth application client secret |

## Requirements

- Discourse 3.x or later
- osu! API v2 credentials

## License

[MIT](LICENSE)
