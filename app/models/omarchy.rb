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
#
# Every read answers rather than raises, and rescues SystemCallError rather
# than Errno::ENOENT alone. A theme path can be unreadable as easily as it can
# be absent — a container handed the wrong home directory is enough, and so is
# a stray chmod — and the two want the same answer. Rescuing only the missing
# case meant an EACCES came back up through the layout, so a desktop this could
# not read took every page in the app down with it rather than costing it a
# palette.
module Omarchy
  STATE = Pathname.new(Dir.home).join(".local", "state", "omarchy", "current")

  class << self
    def stylesheet
      STATE.join("theme", "uplink.css")
    end

    def wallpaper
      path = STATE.join("background")
      path.realpath if path.exist?
    rescue SystemCallError
      nil
    end

    # Pulled back out of the CSS Omarchy rendered for us, so even the favicon
    # follows the desktop. The app has no other reason to know a colour.
    def accent
      stylesheet.read[/--accent:\s*(#[0-9a-fA-F]{3,8})/, 1] || "#7aa2f7"
    rescue SystemCallError
      "#7aa2f7"
    end

    def background
      stylesheet.read[/--bg:\s*(#[0-9a-fA-F]{3,8})/, 1] || "#16161e"
    rescue SystemCallError
      "#16161e"
    end

    # "light" or "dark", straight out of the `color-scheme` line the theme
    # template emits from the theme's own `mode` key. The grove asks because it
    # needs to know whether to hang a sun or a moon in the sky, and the desktop
    # has already made that decision better than the clock could.
    def mode
      stylesheet.read[/color-scheme:\s*(light|dark)/, 1] || "dark"
    rescue SystemCallError
      "dark"
    end

    def theme_name
      STATE.join("theme.name").read.strip
    rescue SystemCallError
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
    rescue SystemCallError
      "monospace"
    end

    # Bumped whenever anything the desktop decides changes, so the browser is
    # asked for a URL it has never seen and cannot answer from cache.
    #
    # The wallpaper counts, not just the palette. It is fetched by URL like the
    # stylesheet is, and it moves on its own: cycling backgrounds inside a theme
    # rewrites the symlink without touching uplink.css, so keying only on the
    # stylesheet would leave the browser showing the previous picture.
    #
    # The link rather than the picture, and so `lstat` rather than `mtime`.
    # Every background in a theme was written when the theme was installed and
    # they all share a timestamp; what moves when you cycle them is which one
    # the link points at.
    def revision
      [ stylesheet, background_link ].filter_map { |path| stamp(path) }.max || 0
    end

    def background_link = STATE.join("background")

    def stamp(path)
      path.lstat.mtime.to_i
    rescue SystemCallError
      nil
    end

    def forget!
      @font = nil
    end
  end
end
