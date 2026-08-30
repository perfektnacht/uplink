# Rails 8 does not draw the routes until something asks for them, which is
# normally the first request. Turbo broadcasts render partials from a job
# thread instead, and a probe finishing before anyone has opened the page gets
# there first — so a partial naming node_path blows up in the background while
# the page itself renders fine. Draw them at boot and the ordering stops
# mattering.
Rails.application.config.after_initialize do
  Rails.application.reload_routes_unless_loaded
end
