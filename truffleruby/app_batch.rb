require "rdkafka"
require "active_record"
require "json"

ActiveRecord::Base.establish_connection(
    url: ENV.fetch("DATABASE_URL"),
    pool: 5
)

class KioskEvent < ActiveRecord::Base
    self.table_name = "kiosk_events"
end

engine = ENV.fetch("ENGINE", "unknown")
config = {
    "bootstrap.servers" => ENV.fetch("BOOTSTRAP_SERVERS", "localhost:9092"),
    "group.id"          => engine,
}

topic = ENV.fetch("TOPIC", "jobs")

rdkafka = Rdkafka::Config.new(config)
consumer = rdkafka.consumer
consumer.subscribe(topic)

trap("INT")  { puts "\nEncerrando..."; consumer.close; exit 0 }
trap("TERM") { puts "\nEncerrando..."; consumer.close; exit 0 }

puts "[AR]: Consumindo de #{topic}…"
puts "using engine #{engine}"

batch = []
batch_size = 2000

loop do
    begin
        msg = consumer.poll(10)
        next unless msg

        payload = JSON.parse(msg.payload, symbolize_names: true)
        
        # Pra diferenciar
        event_type = "#{engine}_#{payload[:eventType]}"
        
        batch << {
            mall_id: payload[:mallId],
            kiosk_id: payload[:kioskId],
            event_type: event_type,
            event_ts: payload[:eventTs],
            amount_cents: payload[:amountCents],
            total_items: payload[:totalItems],
            payment_method: payload[:paymentMethod],
            status: payload[:status] || payload["status"],
            created_at: Time.now,
            updated_at: Time.now
        }
        
        if batch.size >= batch_size
            begin
                KioskEvent.insert_all(batch)
                puts "Inserted batch of #{batch.size} records"
                batch.clear
            rescue ActiveRecord::RecordInvalid, ActiveRecord::ActiveRecordError => e
                warn "Database error: #{e}"
                batch.clear
            end
        end
        
    rescue Rdkafka::RdkafkaError => e
        warn "Exceção rdkafka: #{e}"
    end
end
