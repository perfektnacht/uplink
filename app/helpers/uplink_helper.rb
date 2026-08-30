module UplinkHelper
  def dot_title(probeable)
    case probeable.status
    when "up"   then "up#{" · #{probeable.latency_ms}ms" if probeable.latency_ms}"
    when "down" then "down · #{probeable.probes.last&.error}"
    else "not probed"
    end
  end
end
