ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Omarchy is the machine this is running on, and the tests kept quietly
    # asking it questions. A theme test that compared the stamp under a stubbed
    # light theme against the real one proved nothing on a desktop already set
    # to light; one that asserted a wallpaper URL passed here and failed on CI,
    # where there is no desktop at all. Three of those in as many days.
    #
    # So anything that depends on what the desktop says says it here instead.
    def with_desktop(mode: "dark", font: "Test Mono", wallpaper: Pathname.new("/tmp/uplink-test-background"))
      was = %i[ mode font wallpaper ].to_h { |name| [ name, Omarchy.method(name) ] }

      Omarchy.define_singleton_method(:mode) { mode }
      Omarchy.define_singleton_method(:font) { font }
      Omarchy.define_singleton_method(:wallpaper) { wallpaper }

      yield
    ensure
      was.each { |name, method| Omarchy.define_singleton_method(name, method) }
    end
  end
end
