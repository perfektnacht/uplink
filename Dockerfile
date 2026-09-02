# syntax=docker/dockerfile:1
#
# Uplink in a container, for a machine where installing Ruby 3.4 and a bundle
# of gems is more trouble than it is worth. It is an alternative to the systemd
# unit, not a different program: the same one process serving the pages and
# running the probes, on the same loopback address, with the same absence of a
# login screen.
#
# That last part is why this image is built the way it is. Uplink has no
# authentication because it binds to 127.0.0.1 and is therefore only reachable
# from the machine it runs on. A container that published a port would be
# quietly moving that boundary, so this one does not: docker-compose.yml runs
# it in the host's own network namespace, where `bind "tcp://127.0.0.1:3030"`
# means the same thing inside the container as it does outside. There is no
# EXPOSE line for the same reason — an app with no login is not a thing to
# advertise as publishable.

ARG RUBY_VERSION=3.4.10
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Three of these are here because the app shells out to them and one is for the
# healthcheck. `ping`, because an ICMP probe borrows the system's setuid ping
# rather than opening a raw socket Uplink should not have. `ip`, because
# db:seed reads the routing table to find your gateway instead of guessing at
# 192.168.1.1. `curl`, for the healthcheck below.
#
# fontconfig is here so `Omarchy.font` has an fc-match to ask. It could be left
# out: the browser rendering the page is on the host, so the `ui-monospace`
# further along the font stack resolves through the host's own fontconfig to
# the same face, and the picture is identical either way. What differs is the
# name written into the stylesheet — "monospace" rather than the family the
# desktop actually chose — and that name is the one the page reports about
# itself. Naming the wrong thing correctly is still naming the wrong thing.
#
# docker-compose.yml mounts what it needs read-only: the font files, and the
# single conf.d file omarchy writes your choice into. Not the host's whole
# /etc/fonts — see the note there for why that cannot be made to work.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl fontconfig iproute2 iputils-ping libcap2-bin libsqlite3-0 tzdata && \
    setcap cap_net_raw+ep "$(command -v ping)" && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Sharing the host's network namespace means the host's ping_group_range
# applies, which on most desktops already permits unprivileged ICMP datagram
# sockets. The capability above is for the machines where it does not, so an
# icmp probe does not report a live host as down on account of a sysctl.

ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    PORT=3030 \
    SOLID_QUEUE_IN_PUMA=1

# fontconfig keeps the scan it makes of the mounted font directories under
# XDG_CACHE_HOME, and would otherwise reach for $HOME — which here is the
# host's, mounted read-only in the two places the theme lives and nowhere else.
# Pointed instead at the tmp this image already owns and can write to.
ENV XDG_CACHE_HOME=/rails/tmp/cache

# The port and the supervisor live here rather than in docker-compose.yml
# because neither is really yours to change: the theme hook curls 3030 by
# name, the seeded "This machine" node probes 3030, and a second process for
# the jobs would be a second thing to keep in sync with the first.


FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Bundler is taken from the lockfile rather than from whatever the base image
# happens to ship, so the container resolves gems the way your machine does.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler --no-document -v "$(awk '/^BUNDLED WITH$/ { getline; print $1 }' Gemfile.lock)" && \
    bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Propshaft serves assets out of the app in development and test only, so
# production reads them from public/assets and an image that skipped this step
# would answer every stylesheet and every importmap module with a 404. The
# dummy key is Rails' own arrangement for the fact that precompiling boots the
# app and booting production wants a secret_key_base that assets do not use.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# uid 1000 is the first human account on a Linux desktop, which is whose
# ~/.local/state/omarchy gets mounted in and whose files the storage volume
# ends up holding. Matching it means the read-only mounts read and the volume
# writes without anything having to run as root to manage it.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p storage tmp log && \
    chown -R rails:rails storage tmp log
USER 1000:1000

# Ruby's Dir.home reads this before it reads the passwd entry, so it is stated
# rather than inherited. docker-compose.yml overrides it with your own $HOME,
# for the reason given there.
ENV HOME=/home/rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# The same command as the systemd unit runs, for the same reason: one process
# is the web server, the job supervisor and the recurring sweep. No Thruster in
# front of it — Thruster is a proxy, it sets X-Forwarded-For, and POST
# /theme/changed refuses a forwarded request on principle.
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
