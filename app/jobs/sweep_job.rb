# Asks everything that is due whether it is still there. Runs every 15 seconds
# from config/recurring.yml, but each node and service carries its own
# interval — the default is a minute — so this mostly finds nothing to do and
# costs a single indexed query.
class SweepJob < ApplicationJob
  queue_as :probes

  def perform
    (Node.due + Service.due).each { |it| ProbeJob.perform_later(it) }
  end
end
