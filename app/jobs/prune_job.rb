# Probes are only interesting while they are recent.
class PruneJob < ApplicationJob
  queue_as :probes

  def perform = Probe.prune
end
