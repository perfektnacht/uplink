# The dependency half of the security posture, as one command. Uplink has no
# login and no boundary but loopback, so a known hole in something it depends
# on is a hole in the whole of it -- and a check nobody can run is a check that
# stops being run.
desc "Check Gemfile.lock against the ruby-advisory-db"
task :audit do
  require "bundler/audit/cli"

  Bundler::Audit::CLI.start([ "check", "--update" ])
end
