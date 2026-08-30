# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_30_032336) do
  create_table "links", force: :cascade do |t|
    t.integer "from_node_id", null: false
    t.integer "to_node_id", null: false
    t.string "kind", default: "ethernet", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_node_id", "to_node_id"], name: "index_links_on_from_node_id_and_to_node_id", unique: true
    t.index ["from_node_id"], name: "index_links_on_from_node_id"
    t.index ["to_node_id"], name: "index_links_on_to_node_id"
  end

  create_table "nodes", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", default: "host", null: false
    t.string "address"
    t.integer "x", default: 0, null: false
    t.integer "y", default: 0, null: false
    t.integer "width", default: 240, null: false
    t.string "probe_kind", default: "none", null: false
    t.integer "probe_port"
    t.string "probe_url"
    t.integer "probe_interval", default: 60, null: false
    t.string "status", default: "unknown", null: false
    t.datetime "last_probed_at"
    t.integer "latency_ms"
    t.string "notes"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "probes", force: :cascade do |t|
    t.string "probeable_type", null: false
    t.integer "probeable_id", null: false
    t.boolean "up", null: false
    t.integer "latency_ms"
    t.string "error"
    t.datetime "created_at", null: false
    t.index ["probeable_type", "probeable_id", "created_at"], name: "index_probes_on_probeable_and_time"
    t.index ["probeable_type", "probeable_id"], name: "index_probes_on_probeable"
  end

  create_table "services", force: :cascade do |t|
    t.integer "node_id", null: false
    t.string "name", null: false
    t.string "url", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.string "probe_kind", default: "http", null: false
    t.integer "probe_port"
    t.string "probe_url"
    t.integer "probe_interval", default: 60, null: false
    t.string "status", default: "unknown", null: false
    t.datetime "last_probed_at"
    t.integer "latency_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["node_id"], name: "index_services_on_node_id"
  end

  create_table "speedtests", force: :cascade do |t|
    t.float "down_mbps"
    t.float "up_mbps"
    t.integer "latency_ms"
    t.string "error"
    t.datetime "created_at", null: false
  end

  add_foreign_key "links", "nodes", column: "from_node_id"
  add_foreign_key "links", "nodes", column: "to_node_id"
  add_foreign_key "services", "nodes"
end
