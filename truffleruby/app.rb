require "rdkafka"
require "pg"
require "json"

# PostgreSQL connection using DATABASE_URL
conn = PG.connect(ENV.fetch("DATABASE_URL"))

# Prepare the insert statement for better performance
insert_sql = <<~SQL
    INSERT INTO kiosk_events (
        mall_id, kiosk_id, event_type, event_ts, amount_cents, 
        total_items, payment_method, status, created_at, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
SQL

conn.prepare("insert_kiosk_event", insert_sql)

config = {
        "bootstrap.servers" => ENV.fetch("BOOTSTRAP_SERVERS", "localhost:9092"),
        "group.id"          => ENV.fetch("GROUP_ID", "g1"),
}

topic = ENV.fetch("TOPIC", "jobs")

rdkafka = Rdkafka::Config.new(config)
consumer = rdkafka.consumer
consumer.subscribe(topic)

cleanup = proc do
    puts "\nEncerrando..."
    consumer.close
    conn.close
    exit 0
end

trap("INT", &cleanup)
trap("TERM", &cleanup)

puts "Consumindo de #{topic}…"
loop do
        begin
                msg = consumer.poll(10)
                next unless msg

                payload = JSON.parse(msg.payload, symbolize_names: true)
                begin
                        event_type = "truffleruby_#{payload[:eventType]}"
                        now = Time.now
                        
                        conn.exec_prepared("insert_kiosk_event", [
                                payload[:mallId],
                                payload[:kioskId],
                                event_type,
                                payload[:eventTs],
                                payload[:amountCents],
                                payload[:totalItems],
                                payload[:paymentMethod],
                                payload[:status] || payload["status"],
                                now,
                                now
                        ])
                rescue PG::Error => e
                        warn "Database error: #{e}"
                end
        rescue Rdkafka::RdkafkaError => e
                warn "Exceção rdkafka: #{e}"
        end
end
