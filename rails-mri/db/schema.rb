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

ActiveRecord::Schema[8.0].define(version: 2025_08_11_214731) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "kiosk_events", force: :cascade do |t|
    t.integer "mall_id", null: false
    t.integer "kiosk_id", null: false
    t.string "event_type", null: false
    t.datetime "event_ts", null: false
    t.integer "amount_cents"
    t.integer "total_items"
    t.string "payment_method"
    t.integer "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mall_id", "kiosk_id", "event_type", "event_ts"], name: "index_kiosk_events_on_mall_kiosk_eventts", unique: true
  end
end
