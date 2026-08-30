require "test_helper"

class ProbeableTest < ActiveSupport::TestCase
  test "nothing without a probe is ever due" do
    assert_not nodes(:switch).due?
    assert_not_includes Node.due, nodes(:switch)
  end

  test "something never probed is due" do
    assert nodes(:router).due?
  end

  test "something probed within its own interval is not due" do
    nodes(:router).update!(last_probed_at: 10.seconds.ago, probe_interval: 60)
    assert_not nodes(:router).due?
    assert_not_includes Node.due, nodes(:router)
  end

  test "something probed longer ago than its interval is due again" do
    nodes(:router).update!(last_probed_at: 90.seconds.ago, probe_interval: 60)
    assert nodes(:router).due?
    assert_includes Node.due, nodes(:router)
  end

  # Each row carries its own interval, and the scope has to respect that
  # rather than applying one global deadline to everything.
  test "the due scope honours per-row intervals" do
    nodes(:router).update!(last_probed_at: 90.seconds.ago, probe_interval: 300)
    nodes(:server).update!(last_probed_at: 90.seconds.ago, probe_interval: 30)

    assert_not_includes Node.due, nodes(:router)
    assert_includes Node.due, nodes(:server)
  end

  # A real probe against a real closed port, rather than a stub. Port 1 on
  # loopback refuses instantly and always, which makes it a better fixture
  # than a mock that only proves the mock was called.
  test "a failed probe records the reason and flips the status" do
    node = closed_port_node

    assert node.probe!, "a status change should report itself"
    assert node.status_down?
    assert_equal "port 1 closed, host answered", node.probes.last.error
    assert_nil node.latency_ms
  end

  test "a probe that finds no change reports no change" do
    node = closed_port_node

    assert node.probe!, "unknown becoming down is a change"
    assert_not node.probe!, "down staying down is not"
    assert_equal 2, node.probes.count, "every reading is still recorded"
  end

  test "a successful probe records how long it took" do
    node = nodes(:router)
    node.update!(probe_kind: "tcp", address: "127.0.0.1", probe_port: open_port, status: "unknown")

    assert node.probe!
    assert node.status_up?
    assert_not_nil node.latency_ms
    assert_nil node.probes.last.error
  end

  private
    def closed_port_node
      nodes(:router).tap do |node|
        node.update!(probe_kind: "tcp", address: "127.0.0.1", probe_port: 1, status: "unknown")
      end
    end

    # A port that is definitely listening: one this test opened.
    def open_port
      @server ||= TCPServer.new("127.0.0.1", 0)
      @teardown_server = true
      @server.addr[1]
    end

    def after_teardown
      super
      @server&.close
    end

  # The message that sent someone to ask why their switch was "down": a refused
  # connection proves the host is there, and saying so points at the port
  # rather than at the network.
  test "a refused port says the host answered" do
    node = closed_port_node
    node.probe!

    assert_match(/host answered/, node.probes.last.error)
    assert_no_match(/connection refused/, node.probes.last.error)
  end

  test "a probe url is tidied on the way in, however it arrived" do
    node = nodes(:router)

    node.update!(probe_url: "http:/192.168.1.40")
    assert_equal "http://192.168.1.40", node.reload.probe_url

    node.update!(probe_url: "192.168.1.40:8080")
    assert_equal "http://192.168.1.40:8080", node.reload.probe_url
  end

  test "a service url is tidied the same way" do
    service = services(:plex)

    service.update!(url: "192.168.1.10:32400")
    assert_equal "http://192.168.1.10:32400", service.reload.url
  end

  test "uptime is unknown until something has been probed" do
    assert_nil nodes(:router).uptime_ratio
  end
end
