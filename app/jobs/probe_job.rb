# One probe against one thing. Separate from the sweep so a modem that has
# stopped answering cannot hold up every other reading behind it.
class ProbeJob < ApplicationJob
  queue_as :probes

  # A host that has gone away will fail the same way next minute; there is
  # nothing to retry into.
  discard_on StandardError

  def perform(probeable)
    probeable.probe!
  end
end
