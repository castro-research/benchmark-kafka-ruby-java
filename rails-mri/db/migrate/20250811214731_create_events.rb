class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :kiosk_events do |t|
      t.integer  :mall_id,         null: false
      t.integer  :kiosk_id,        null: false
      t.string   :event_type,      null: false
      t.datetime :event_ts,        null: false
      t.integer  :amount_cents
      t.integer  :total_items
      t.string   :payment_method
      t.integer  :status,          null: false

      t.timestamps

      # unique constraint
      t.index [:mall_id, :kiosk_id, :event_type, :event_ts], unique: true, name: 'index_kiosk_events_on_mall_kiosk_eventts'
    end
  end
end
