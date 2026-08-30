# Serves the desktop's own palette to the browser, and lets the desktop say
# when it changed. Between the two, switching an Omarchy theme repaints an
# open Uplink tab without reloading it.
class ThemeController < ApplicationController
  # The theme-set and font-set hooks are shell scripts with curl; they have no
  # session and no token to send. Forgery protection is skipped only here, and
  # only for a request that arrives from this machine and does nothing but
  # re-read two files.
  skip_forgery_protection only: :changed
  before_action :require_loopback, only: :changed

  # No caching of any kind: this file's whole job is to be different after a
  # theme switch, and a 304 would defeat the point.
  def stylesheet
    if Omarchy.stylesheet.exist?
      send_file Omarchy.stylesheet, type: "text/css", disposition: "inline"
    else
      render plain: MISSING_TEMPLATE_CSS, content_type: "text/css"
    end
  end

  # The window icon, in the desktop's own colours. Chromium asks for a favicon
  # on every load and Uplink runs as an Omarchy web app, so the alternative was
  # a routing error in the log and a blank square in the launcher.
  def icon
    render formats: :svg, content_type: "image/svg+xml"
  end

  def wallpaper
    if (path = Omarchy.wallpaper)
      send_file path, disposition: "inline"
    else
      head :no_content
    end
  end

  def changed
    Omarchy.forget!

    Turbo::StreamsChannel.broadcast_replace_to "omarchy",
      target: "theme-stylesheet", partial: "theme/stylesheet"

    # The name in the corner is the one piece of the page that says which theme
    # this is, so it has to change when the theme does.
    Turbo::StreamsChannel.broadcast_replace_to "omarchy",
      target: "theme-name", partial: "uplink/theme_name"

    # The canvas only needs the new palette. The grove needs to be redrawn: a
    # light theme hangs a sun where the moon was, and that is markup, not CSS.
    Grove.redraw

    head :no_content
  end

  private
    def require_loopback
      head :forbidden unless request.remote_ip.in?(%w[ 127.0.0.1 ::1 ])
    end

    # Shown when bin/omarchy-install has not run yet, so the app is legible
    # instead of unreadable while you go fix it.
    MISSING_TEMPLATE_CSS = <<~CSS
      :root {
        color-scheme: dark;
        --bg: #16161e; --bg-abyss: #0d0d12; --bg-sunk: #111117; --bg-raised: #24242e;
        --fg: #c0caf5; --fg-dim: #565f89; --fg-soft: #a9b1d6; --fg-bright: #ffffff;
        --muted: #414868; --selection: #292e42; --accent: #7aa2f7;
        --up: #9ece6a; --down: #f7768e; --warn: #e0af68;
        --bg-rgb: 22,22,30; --fg-rgb: 192,202,245; --muted-rgb: 65,72,104;
        --accent-rgb: 122,162,247; --up-rgb: 158,206,106; --down-rgb: 247,118,142;
        --warn-rgb: 224,175,104; --blue-rgb: 122,162,247; --cyan-rgb: 68,157,171;
        --red: #f7768e; --green: #9ece6a; --yellow: #e0af68; --blue: #7aa2f7;
        --magenta: #ad8ee6; --cyan: #449dab;
      }
      body::after {
        content: "Run bin/omarchy-install to wire Uplink to your Omarchy theme.";
        position: fixed; inset: auto 0 0 0; padding: .6rem;
        background: #e0af68; color: #16161e; text-align: center; z-index: 999;
      }
    CSS
end
