# The other half of the security posture. `bin/rails audit` checks what Uplink
# depends on; this checks what Uplink is. Warnings reviewed and deliberately
# accepted live in config/brakeman.ignore with a note saying why.
desc "Static analysis of the app's own code"
task :brakeman do
  require "brakeman"

  result = Brakeman.run(app_path: Rails.root.to_s, print_report: true, pager: false,
                        ignore_file: Rails.root.join("config/brakeman.ignore").to_s)

  abort "brakeman found warnings" if result.filtered_warnings.any?
end
