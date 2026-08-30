# Uplink

A homelab dashboard shaped like the network it describes.

Most self-hosted dashboards are a grid of bookmark tiles with a YAML file
behind them. None of them know what your network *looks like*. Uplink draws the
thing you actually have — internet arriving, the modem, the router, Pi-hole
doing DNS off to one side, a switch, the box that runs everything — and puts
the links to your services inside the machine that serves them.

It runs on `127.0.0.1`, it repaints itself when you switch Omarchy themes, and
it has no login screen.

![Uplink on the evergreen theme](doc/uplink.png)

## What it is

Rails 8 on SQLite. Solid Queue for the probes, Solid Cable for the live
updates, Solid Cache for the rest. Hotwire, Propshaft, importmaps.

No Node. No `package.json`, no `node_modules`, no build step, no bundler for
JavaScript. No Tailwind — every color comes from your theme. No Docker, no
Redis, no Postgres. One process, one unit file, four SQLite files in
`storage/`.

The whole thing is about fifteen files you can read in ten minutes.

## No authentication, on purpose

There is no login, no 2FA, no OIDC, and that is a decision rather than a
shortcut. Uplink binds to loopback — enforced in `config/puma.rb`, not just in
the unit file — stores nothing but the shape of your own LAN, and every service
it shows is a hyperlink you could have typed yourself. A login screen would
protect a machine you are already sitting at from a person who is already you.

CSRF protection stays on for everything that writes, because that guards
against a website you visit, not against you. The one exception is
`POST /theme/changed`, which is a shell hook with no session to carry a token,
and which is refused unless it comes from loopback.

## Privacy

`p`, or the toolbar button, paints over every address on the canvas so the
window can be screenshotted and posted somewhere public without anyone having
to blur it by hand. The text is redacted rather than blurred: a blur at this
size is guessable and still leaks the shape of a number, while a solid bar
leaks nothing — and keeping the original text underneath means no card changes
width, so the diagram looks identical either way. The setting is remembered per
browser.

It covers what is drawn. A service link still points at a real host, so the
status bar will show it if you screenshot mid-hover.

URL fields are forgiving, and are plain text rather than `type="url"`. A field
that rejects `192.168.1.10:8080` for having no scheme is being pedantic about
a machine you can see from where you are sitting, so anything scheme-less gets
`http://`, surrounding whitespace is dropped, and `http:/host` — a scheme that
lost a slash, which is what a password manager rewriting the field as you type
can leave behind — is repaired. A `type="url"` input is also exactly what those
extensions read as a "website" field, so it is not one.

Every field in the inspector carries `data-1p-ignore`, `data-lpignore` and
`data-bwignore`, and its form is `autocomplete="off"`. Nothing here is a
credential, but a panel of text fields looks enough like a login that password
managers offer to save it as an identity.

Do not put this on the internet. It is not built for that and says so here so
you cannot say you were not told.

## Living inside Omarchy

This is the part that is not portable, and is the reason the app exists in this
shape.

Omarchy renders every template in `~/.config/omarchy/themed/*.tpl` into the
staged theme directory on each theme switch. Uplink ships one:

```
omarchy/uplink.css.tpl  →  ~/.local/state/omarchy/current/theme/uplink.css
```

So the app never parses a palette, never reads `colors.toml`, and does no color
math. It serves a CSS file the desktop already wrote, at `/theme.css`. Thirty-
odd custom properties, including `_rgb` variants for translucency and
`color-scheme` taken from the theme's own `mode` key — which is what lets the
stylesheet use `light-dark()` and get the shadows right on a light theme
without knowing which theme is active.

Then `omarchy-theme-set` fires its `theme-set` hook, and Uplink's hook is three
lines of curl. The app broadcasts a Turbo Stream replacing one `<style>`
element, and the browser refetches one small file. No reload, and your canvas
position survives.

Measured on the machine this was built on: the hook's POST returns in 10–40ms,
and `/theme.css` is 1845 bytes served in about 3ms. The repaint is the tail end
of a theme switch that takes ~570ms overall, so it lands while the wallpaper is
still crossfading.

The hook has a two-second timeout and swallows its own failures, so a stopped
Uplink can never slow down or noisily fail a theme switch. Measured: ~500ms
with the service down, ~570ms with it up.

A theme that ships its own `uplink.css` overrides the template entirely —
`omarchy-theme-set-templates` refuses to overwrite an output file that already
exists — so a theme author can art-direct Uplink without touching Uplink.

The desktop wallpaper is read through the same state directory and rendered
blurred behind the canvas, so Uplink sits in the same room as the rest of the
desktop rather than on a slab on top of it.

## Probing

A node or a service is up if it answers, and the answer is one of three
questions: a TCP handshake, an HTTP request, or an ICMP echo borrowed from the
setuid `ping` already on the system.

The polling budget is the design constraint. Every row carries its own
`probe_interval` — sixty seconds by default — SQLite does the due-date
arithmetic in one indexed query, and a probe that changes nothing broadcasts
nothing. An idle dashboard sends zero frames and moves nothing beyond one small
query every fifteen seconds.

Self-signed certificates are accepted, because refusing to talk to a homelab
box with its own cert would report a working service as down, which is a worse
lie than not checking.

A cable is drawn live when nothing along it is known to be broken — not when
both ends answered. An unmanaged switch answers nothing and never will; letting
that silence grey out the whole chain behind it would report ignorance as
failure.

## Speedtest

Measured against Cloudflare's `speed.cloudflare.com` endpoints, which are plain
HTTP with no client to install and no account to have.

The reading is kept on the Internet card, where the thing it measures is; the
button that takes it sits in the toolbar, because a control is not a fact.
It is manual by default. There is a commented entry in `config/recurring.yml`
if you want it nightly. A dashboard that quietly pulls thirty megabytes every
few minutes to draw you a number is measuring a problem it created.

## The canvas

Absolutely-positioned HTML cards over one SVG layer of cables — not a drawing
surface. That is the load-bearing decision: a service inside a node stays a
real `<a>`, so it is keyboard-reachable, middle-clickable into a new tab, and
themed by the same tokens as everything else. Nothing is reimplemented in a
canvas API.

Cables route orthogonally, leaving a card square-on and turning at right
angles, because that is how a rack diagram reads. Each is two paths: the base
carries the kind — coax is thick, wifi and logical are dashed, fiber is tinted
— and an overlay carries the drift that shows it is alive. Folded into one,
"live" would have had to own the dash pattern, and a coax run would have become
indistinguishable from a DNS relationship.

`logical` is for a link that is real but not physical. The router pointing at
Pi-hole for DNS travels over the same ethernet as everything else, and drawing
it as another wire would be a lie — so a Pi-hole usually wants both: an
`ethernet` cable to whatever switch it is plugged into, and a `logical` link
from the router that resolves through it.

A `logical` link is drawn as a chip on the card that depends on it, not as a
cable. The relationship is many-to-one — every machine on the network can point
at one Pi-hole — and a line from each of them would be noise rather than
information. The chip says whatever the link's label says: *DNS*, *VPN*, *NTP*.
Click one in edit mode to change it.

Note which way round that goes: the Raspberry Pi is the `host`, and Pi-hole is
a `service` running on it. Modelling it the other way makes a machine disappear
behind one of its own programs, and you lose the ability to see that the box is
up while the service on it is not.

A node's kind is free text, offered as suggestions rather than enforced as a
list. A closed enum kept failing real networks — a Pi-hole is not an appliance,
a Hue bridge is not one either — and every miss cost a migration. Whatever you
type gets a stable colour derived from the theme, so a kind Uplink has never
heard of still looks deliberate. Green, red and yellow are never used for a
kind: those three mean up, down and degraded, and a label wearing one would be
arguing with the status dot beside it. `host` is deliberately the quiet one,
because colouring the commonest kind leaves nothing to mark the infrastructure.

It is written out rather than drawn as an icon. Which glyphs exist depends on
whichever Nerd Font is currently set, and a router that renders as a plug is
worse than no icon at all.

| key | |
|---|---|
| `e` | toggle edit mode |
| `0` | fit everything on screen |
| `p` | privacy: redact every address |
| `Esc` | close the inspector |
| middle-drag, or drag the background | pan |
| ctrl + wheel | zoom toward the cursor |
| drag a card's `wire` handle onto another card | draw a cable |
| hold shift while dropping | make it a logical link |
| click a cable (edit mode) | change its kind or label, or delete it |

While you drag, a card looks for a neighbour it is nearly in line with and
locks onto it, drawing a guide to show what it caught. Centres outrank edges
even when an edge is closer: a cable leaves a card from the middle of a face,
so aligning centres is what makes the line straight, while aligning edges only
makes the layout tidy. Otherwise positions snap to an 8px grid, and save on drop. They live in the database
because you put them there; nothing is computed. The viewport, by contrast,
lives in `localStorage`, because where *you* are looking is not part of the
network.

## Install

Needs Ruby (3.4 is what Omarchy ships) and Bundler.

```bash
gem install --user-install bundler rails
git clone https://github.com/perfektnacht/uplink ~/Work/github.com/perfektnacht/uplink
cd ~/Work/github.com/perfektnacht/uplink
bundle install

bin/omarchy-install                 # theme template, hooks, service, launcher
bin/rails db:prepare db:seed        # seeds from `ip route` and your own dashboard services
systemctl --user enable --now uplink
```

Then open it, or run `omarchy-launch-webapp http://localhost:3030`.

`bin/omarchy-install --with-hyprland` also appends a marker-delimited window
rule to `~/.config/hypr/looknfeel.lua`. Without the flag it just prints the
line, because your Hyprland config is yours and an installer that edits it
behind your back is a bad guest.

Everything it touches lives under `~/.config`, `~/.local/share`, or
`~/.local/state`. Nothing goes in `/usr/share/omarchy`, which the omarchy
package owns and rewrites on update.

## Uninstall

```bash
bin/omarchy-uninstall
```

Removes the service, the template, both hooks, the launcher, and the Hyprland
block if the installer added one. `storage/` is left alone — delete it if you
want the network forgotten too.

## Development

```bash
bin/dev            # one process: server, jobs, and the recurring sweep
bin/rails test
```

Development runs the same job backend as production, because the jobs are the
feature — a dashboard that does not poll in development is one you cannot
develop.

The tests probe port 1 on loopback, which refuses instantly and always, rather
than stubbing the socket. A mock would only prove the mock was called.
