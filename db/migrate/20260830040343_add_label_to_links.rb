class AddLabelToLinks < ActiveRecord::Migration[8.0]
  def change
    # What a logical link is for: "DNS", "VPN", "NTP". Physical cables rarely
    # need one, which is why it is optional rather than a kind of its own.
    add_column :links, :label, :string
  end
end
