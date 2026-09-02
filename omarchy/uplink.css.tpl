/* Uplink — rendered by omarchy-theme-set from the active theme's colors.toml.
 *
 * Installed by uplink/bin/uplink-install. Every theme switch rewrites this
 * file into ~/.local/state/omarchy/current/theme/uplink.css, which Uplink
 * serves at /theme.css. Nothing here is parsed by the app — it is already CSS.
 *
 * A theme that ships its own uplink.css overrides this template entirely
 * (omarchy-theme-set-templates refuses to overwrite an existing output file),
 * so a theme author can art-direct Uplink without touching Uplink.
 *
 * `orange` is missing from a few stock themes, so never use --orange without a
 * fallback: var(--orange, var(--warn)).
 */

:root {
  color-scheme: {{ mode }};

  /* surfaces, sunk to raised */
  --bg:          {{ background }};
  --bg-abyss:    {{ darker_background }};
  --bg-sunk:     {{ dark_background }};
  --bg-raised:   {{ lighter_background }};
  --bg-rgb:      {{ background_rgb }};

  /* type */
  --fg:          {{ foreground }};
  --fg-dim:      {{ dark_foreground }};
  --fg-soft:     {{ light_foreground }};
  --fg-bright:   {{ bright_foreground }};
  --fg-rgb:      {{ foreground_rgb }};

  --muted:       {{ muted }};
  --muted-rgb:   {{ muted_rgb }};
  --selection:   {{ selection }};

  --accent:      {{ accent }};
  --accent-rgb:  {{ accent_rgb }};

  /* status — the only three colors that carry meaning */
  --up:          {{ green }};
  --up-rgb:      {{ green_rgb }};
  --down:        {{ red }};
  --down-rgb:    {{ red_rgb }};
  --warn:        {{ yellow }};
  --warn-rgb:    {{ yellow_rgb }};

  /* palette, for node accents chosen per-kind */
  --red:         {{ red }};
  --green:       {{ green }};
  --yellow:      {{ yellow }};
  --blue:        {{ blue }};
  --blue-rgb:    {{ blue_rgb }};
  --magenta:     {{ magenta }};
  --cyan:        {{ cyan }};
  --cyan-rgb:    {{ cyan_rgb }};
  --orange:      {{ orange }};

  --bright-red:     {{ bright_red }};
  --bright-green:   {{ bright_green }};
  --bright-yellow:  {{ bright_yellow }};
  --bright-blue:    {{ bright_blue }};
  --bright-magenta: {{ bright_magenta }};
  --bright-cyan:    {{ bright_cyan }};
}
