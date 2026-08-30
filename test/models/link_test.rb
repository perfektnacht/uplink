require "test_helper"

class LinkTest < ActiveSupport::TestCase
  test "a cable between two answering nodes is live" do
    assert links(:uplink).live?
  end

  # The case this exists for: an unmanaged switch answers nothing and never
  # will. Treating that silence as failure would grey out every cable behind it.
  test "a cable through an unprobeable node stays live" do
    assert nodes(:switch).status_unknown?
    assert links(:downlink).live?
  end

  test "a cable to something known to be down is not live" do
    assert_not links(:dead).live?
  end

  test "a node cannot be cabled to itself" do
    link = Link.new(from_node: nodes(:router), to_node: nodes(:router))
    assert_not link.valid?
    assert_includes link.errors[:to_node], "is the same node"
  end

  # A cable is the same cable whichever end you started from, and the unique
  # index only sees an exact repeat.
  test "the same cable cannot be drawn backwards either" do
    link = Link.new(from_node: nodes(:router), to_node: nodes(:internet))

    assert_not link.valid?
    assert_includes link.errors[:base], "these are already cabled together"
  end

  test "reversing an existing cable does not trip over itself" do
    link = links(:uplink)
    link.from_node, link.to_node = link.to_node, link.from_node

    assert link.valid?, link.errors.full_messages.to_sentence
  end

  test "the same cable cannot be drawn twice" do
    assert_raises ActiveRecord::RecordNotUnique do
      Link.create!(from_node: nodes(:internet), to_node: nodes(:router))
    end
  end
end
