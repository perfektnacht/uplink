require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Rails will not boot in production without a secret_key_base, and the usual
  # place to keep one is config/credentials.yml.enc — which is decrypted with
  # config/master.key, which is gitignored, which means nobody who clones this
  # has ever had one. Left to the default, the first thing a fresh install does
  # is refuse to start and blame the credentials for it.
  #
  # So one is generated on first boot and kept in storage/, beside the four
  # SQLite files, because it is the same kind of thing: local state belonging
  # to this checkout and to nothing else. Rails already does exactly this in
  # development and test, in tmp/local_secret.txt. Production differs only in
  # declining to do it for you, which is the right default for an app deployed
  # to a machine full of other people's things and the wrong one for this.
  #
  # What it signs is the CSRF tokens in the forms, and a session cookie for an
  # app that keeps nothing in the session. Both are worth signing; neither is
  # worth a key ceremony, because anyone who can read this file is already
  # reading the database sitting next to it.
  config.secret_key_base =
    if ENV["SECRET_KEY_BASE"].present?
      ENV["SECRET_KEY_BASE"]
    elsif ENV["SECRET_KEY_BASE_DUMMY"].present?
      # How Rails says "this boot is a build step, not a server": it is what
      # precompiling assets into a Docker layer sets. Honouring it is not
      # pedantry — without this branch the build would generate a real secret
      # and COPY it into the image, and every install made from that image
      # would then be signing its cookies with the same one.
      SecureRandom.hex(64)
    else
      secret = Rails.root.join("storage", "secret_key_base")

      unless secret.exist?
        secret.dirname.mkpath
        secret.write(SecureRandom.hex(64), perm: 0600)
      end

      secret.read.strip
    end

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # There is no SSL-terminating reverse proxy, because there is no proxy: Uplink
  # binds to 127.0.0.1 and is reached over plain http at localhost:3030.
  #
  # Leaving Rails' defaults on here is not merely redundant, it breaks every
  # form in the app. assume_ssl makes request.base_url report https, the browser
  # sends an http Origin on a form POST, the two disagree, and CSRF rejects the
  # request with a 422 whose body is an error page rather than a turbo-frame —
  # which Turbo reports to the user as the wonderfully unhelpful
  # "Content missing". Nothing saves, and nothing says why.
  config.assume_ssl = false
  config.force_ssl = false

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Host authorization is set for every environment in config/application.rb:
  # loopback is the whole of Uplink's security boundary, so it is not a
  # production-only concern.
end
