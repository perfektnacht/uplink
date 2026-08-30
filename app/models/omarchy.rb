# The desktop, as far as Uplink is concerned.
#
# Omarchy stages the active theme at ~/.local/state/omarchy/current/theme and,
# on every theme switch, renders ~/.config/omarchy/themed/uplink.css.tpl into
# that directory as plain CSS. So there is no palette to parse and no color
# math to do here — only two paths to follow and a font to ask about.
#
# The staging is atomic (omarchy-theme-set moves the directory into place
# before it fires the theme-set hook), which is why reading these files
# straight off disk mid-switch is safe.
module Omarchy
  STATE = Pathname.new(Dir.home).join(".local", "state", "omarchy", "current")

  class << self
    def stylesheet
      STATE.join("theme", "uplink.css")
    end

    def wallpaper
      path = STATE.join("background")
      path.realpath if path.exist?
    rescue Errno::ENOENT
      nil
    end

    def theme_name
      STATE.join("theme.name").read.strip
    rescue Errno::ENOENT
      "unknown"
    end

    # fontconfig is the source of truth, the same one `omarchy font current`
    # consults. Memoized because it costs a subprocess and only changes when
    # the font-set hook tells us it did.
    def font
      @font ||= begin
        name = `fc-match monospace -f '%{family}'`.split(",").first.to_s
        # This lands inside a <style> block, so keep it to the characters a
        # font family can actually contain. A family named "</style>" is not
        # a threat model so much as a courtesy to the parser.
        name = name.gsub(/[^A-Za-z0-9 _-]/, "").squish
        name.presence || "monospace"
      end
    rescue Errno::ENOENT
      "monospace"
    end

    # Bumped whenever the theme or font changes, so the browser is asked for a
    # stylesheet URL it has never seen and cannot serve from cache.
    def revision
      stylesheet.mtime.to_i
    rescue Errno::ENOENT
      0
    end

    def forget!
      @font = nil
    end
  end
end
