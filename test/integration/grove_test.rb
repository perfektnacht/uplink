require "test_helper"

class GroveIntegrationTest < ActionDispatch::IntegrationTest
  test "the grove renders as one svg document" do
    get grove_path

    assert_response :success
    assert_select "svg#grove-scene", 1
    assert_select "svg .bough", minimum: 1
  end

  # The fixture server is down, so nothing in the default network is leafy.
  test "a node that is answering carries leaves, all of them in one path" do
    nodes(:server).update!(status: "up")

    get grove_path

    assert_select "svg .leaves--live", 1
  end

  # Thousands of twigs would be thousands of elements if each carried its own
  # width. Each one's width is in its outline instead, so they concatenate —
  # into one path per tone: fine and thick, above ground and below it.
  test "the whole tangle of twigs is four paths" do
    get grove_path

    assert_select "svg .twig", 4
  end

  # The grove is something you look at, so there is nothing on it to click.
  test "nothing in the scene is clickable" do
    get grove_path

    assert_select "svg a", 0
  end

  test "the bottom bar moves between the two views and says which one you are on" do
    get root_path
    assert_select ".hud__view--on", text: "canvas"
    assert_select ".hud__view[href=?]", grove_path

    get grove_path
    assert_select ".hud__view--on", text: "Yggdrasil"
    assert_select ".hud__view[href=?]", root_path
  end

  # The canvas is where you edit; those controls do not follow you into a
  # picture that cannot be edited.
  test "the grove drops every control, including the speedtest" do
    get grove_path

    # The grove is something you look at. The orb is still sized by the last
    # speedtest, but taking one is an action and actions live on the canvas.
    assert_select "[data-controller=speedtest]", 0
    assert_select "[data-action*=toggleMode]", 0
    assert_select "a[href=?]", new_node_path, 0
  end

  # The scene is wordless at rest, so something has to say where the words are.
  test "the picture says where there is something to point at" do
    get grove_path

    assert_select "g.offering", minimum: Node.count
    # Each swings on its own beat, which is what the phase is carried for.
    assert_match(/--dur: [\d.]+s; --delay: [\d.]+s/, response.body)
  end

  test "the canvas is untouched" do
    get root_path

    assert_response :success
    assert_select "#nodes .node", minimum: 1
    assert_select "svg#grove-scene", 0
  end

  # The scene is cached on Grove.stamp. Test runs with a null store, so this
  # puts a real one in for the duration -- otherwise the thing being tested is
  # switched off.
  test "the same network is drawn once and served twice" do
    with_caching do
      drawn = count_draws { get grove_path }

      assert_equal 1, drawn, "the first look has to grow the tree"
      assert_response :success

      again = count_draws { get grove_path }

      assert_equal 0, again, "the second look grew it again instead of reading it"
      assert_select "svg#grove-scene", 1
    end
  end

  test "a change to the network draws it afresh" do
    with_caching do
      count_draws { get grove_path }
      nodes(:router).update!(status: "down")

      assert_equal 1, count_draws { get grove_path }, "a status change did not reach the picture"
    end
  end

  private
    def with_caching
      store = ActionController::Base.cache_store
      caching = ActionController::Base.perform_caching
      ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
      ActionController::Base.perform_caching = true
      yield
    ensure
      ActionController::Base.cache_store = store
      ActionController::Base.perform_caching = caching
    end

    # Counts the trees actually grown, which is the only thing the cache is
    # there to avoid.
    def count_draws
      drawn = 0
      tracer = Module.new do
        define_method(:draw) { |*a, **k| drawn += 1; super(*a, **k) }
      end
      Grove.singleton_class.prepend(tracer)
      yield
      drawn
    end
end
