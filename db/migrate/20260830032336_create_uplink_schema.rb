class CreateUplinkSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :nodes do |t|
      t.string  :name,           null: false
      t.string  :kind,           null: false, default: "host"
      t.string  :address
      t.integer :x,              null: false, default: 0
      t.integer :y,              null: false, default: 0
      t.integer :width,          null: false, default: 240
      t.string  :probe_kind,     null: false, default: "none"
      t.integer :probe_port
      t.string  :probe_url
      t.integer :probe_interval, null: false, default: 60
      t.string  :status,         null: false, default: "unknown"
      t.datetime :last_probed_at
      t.integer :latency_ms
      t.string  :notes
      t.integer :position,       null: false, default: 0
      t.timestamps
    end

    create_table :links do |t|
      t.references :from_node, null: false, foreign_key: { to_table: :nodes }
      t.references :to_node,   null: false, foreign_key: { to_table: :nodes }
      t.string     :kind,      null: false, default: "ethernet"
      t.timestamps
    end
    add_index :links, %i[ from_node_id to_node_id ], unique: true

    create_table :services do |t|
      t.references :node,        null: false, foreign_key: true
      t.string  :name,           null: false
      t.string  :url,            null: false
      t.string  :icon
      t.integer :position,       null: false, default: 0
      t.string  :probe_kind,     null: false, default: "http"
      t.integer :probe_port
      t.string  :probe_url
      t.integer :probe_interval, null: false, default: 60
      t.string  :status,         null: false, default: "unknown"
      t.datetime :last_probed_at
      t.integer :latency_ms
      t.timestamps
    end

    # One reading. Kept for a day so a status dot can show a recent history
    # without the database growing without bound.
    create_table :probes do |t|
      t.references :probeable, null: false, polymorphic: true
      t.boolean  :up,          null: false
      t.integer  :latency_ms
      t.string   :error
      t.datetime :created_at,  null: false
    end
    add_index :probes, %i[ probeable_type probeable_id created_at ],
      name: "index_probes_on_probeable_and_time"

    create_table :speedtests do |t|
      t.float    :down_mbps
      t.float    :up_mbps
      t.integer  :latency_ms
      t.string   :error
      t.datetime :created_at, null: false
    end
  end
end
