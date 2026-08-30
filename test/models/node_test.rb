require "test_helper"

class NodeTest < ActiveSupport::TestCase
  test "a host is only as up as the services inside it" do
    node = nodes(:router)
    node.services.create!(name: "Admin", url: "http://192.0.2.1", status: "down", probe_kind: "http")

    assert node.status_up?
    assert_equal "warn", node.rollup_status
  end

  test "a host with no services rolls up to its own status" do
    assert_equal "up", nodes(:router).rollup_status
  end

  test "a host that is down stays down regardless of its services" do
    assert_equal "down", nodes(:server).rollup_status
  end

  # The guard that keeps an idle dashboard silent: a probe that finds nothing
  # changed still stamps last_probed_at, and that is not news.
  # Adding several nodes in a row used to stack them all on the same spot,
  # where the top one hides the rest.
  test "a new node is placed somewhere free" do
    clear_canvas
    first = Node.create!(name: "One", kind: "host", x: 120, y: 120, width: 240)

    x, y = Node.free_position
    assert_equal 120, x
    assert_operator y, :>, first.y, "a new node landed on top of an existing one"
  end

  test "an empty canvas puts the first node at the origin of the grid" do
    clear_canvas
    assert_equal [ 120, 120 ], Node.free_position
  end

  private
    def clear_canvas
      Link.delete_all
      Service.delete_all
      Node.delete_all
    end

  test "a probe that changes nothing is not worth redrawing" do
    node = nodes(:router)
    node.update!(last_probed_at: Time.current, latency_ms: 4)
    assert_not node.worth_redrawing?
  end

  test "a status change is worth redrawing" do
    node = nodes(:router)
    node.update!(status: "down", last_probed_at: Time.current)
    assert node.worth_redrawing?
  end
end
