require "net/http"

# Measures the line using Cloudflare's speed endpoints, which are plain HTTP
# with no client, no account, and no package to install.
#
# This never runs on a schedule unless you uncomment it in recurring.yml. A
# dashboard that quietly pulls 25MB every few minutes to draw you a number is
# measuring a problem it created.
class SpeedtestJob < ApplicationJob
  queue_as :probes

  DOWN = URI("https://speed.cloudflare.com/__down?bytes=25000000")
  UP   = URI("https://speed.cloudflare.com/__up")
  PAYLOAD = 6_000_000
  TIMEOUT = 45

  def perform
    test = Speedtest.create!(created_at: Time.current)
    test.update!(latency_ms: latency, down_mbps: download, up_mbps: upload)
  rescue => e
    test&.update(error: e.message.truncate(120))
  ensure
    Turbo::StreamsChannel.broadcast_replace_to "canvas",
      target: "speedtest", partial: "speedtests/speedtest",
      locals: { speedtest: Speedtest.latest }
  end

  private
    def latency
      samples = 3.times.map do
        timed { |http| http.head("/__down?bytes=0") }.first
      end
      samples.min
    end

    def download
      elapsed, response = timed { |http| http.get(DOWN.request_uri) }
      mbps(response.body.bytesize, elapsed)
    end

    def upload
      body = "0" * PAYLOAD
      elapsed, = timed { |http| http.post(UP.request_uri, body) }
      mbps(PAYLOAD, elapsed)
    end

    # Returns [ milliseconds, response ].
    def timed
      http = Net::HTTP.new(DOWN.host, DOWN.port)
      http.use_ssl = true
      http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT

      http.start do |client|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = yield client
        [ ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round, response ]
      end
    end

    def mbps(bytes, milliseconds)
      return 0.0 if milliseconds.zero?
      (bytes * 8 / (milliseconds / 1000.0) / 1_000_000).round(1)
    end
end
