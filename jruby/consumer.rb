
require 'json'
require 'time'
require 'java'
require 'logger'
require 'activerecord-jdbc-adapter'

class KioskEvent < ActiveRecord::Base
  enum :status, {
    pending: 0,
    completed: 1,
    failed: 2
  }
end

ActiveRecord::Base.establish_connection({
  adapter: 'postgresql',
  url: 'postgres://bench:bench@postgres/bench',
  pool: 10,
  prepared_statements: false,
  # Otimizações de conexão
  connect_timeout: 5,
  checkout_timeout: 5,
  reaping_frequency: 60
})

LOGGER = Logger.new($stdout)
LOGGER.level = Logger::INFO

java_import 'org.apache.kafka.clients.consumer.KafkaConsumer'
java_import 'org.apache.kafka.common.serialization.StringDeserializer'
java_import 'java.time.Duration'
java_import 'java.util.Properties'
java_import 'java.util.Arrays'

class BenchmarkConsumerJava
  DEFAULTS = {
    'BOOTSTRAP_SERVERS' => 'localhost:9092',
    'GROUP_ID'          => 'g1',
    'TOPIC'             => 'jobs',
    'POLL_MS'           => 50,
    'BATCH_SIZE'        => 1000,  # Aumentado para bulk insert
    'AUTO_OFFSET_RESET' => 'earliest'
  }.freeze

  def initialize
    @config = {
      'BOOTSTRAP_SERVERS' => ENV.fetch('KAFKA_BROKERS', DEFAULTS['BOOTSTRAP_SERVERS']),
      'GROUP_ID'          => ENV.fetch('KARAFKA_GROUP_ID', DEFAULTS['GROUP_ID']),
      'TOPIC'             => ENV.fetch('KAFKA_TOPIC', DEFAULTS['TOPIC']),
      'POLL_MS'           => ENV.fetch('KAFKA_POLL_MS', DEFAULTS['POLL_MS']).to_i,
      'BATCH_SIZE'        => ENV.fetch('KAFKA_BATCH_SIZE', DEFAULTS['BATCH_SIZE']).to_i,
      'AUTO_OFFSET_RESET' => ENV.fetch('KAFKA_AUTO_OFFSET_RESET', DEFAULTS['AUTO_OFFSET_RESET'])
    }

    puts "🔧 Configurando Kafka Consumer (Optimized):"
    puts "   Bootstrap Servers: #{@config['BOOTSTRAP_SERVERS']}"
    puts "   Group ID: #{@config['GROUP_ID']}"
    puts "   Topic: #{@config['TOPIC']}"
    puts "   Batch Size: #{@config['BATCH_SIZE']}"

    props = Properties.new
    props.put('bootstrap.servers', @config['BOOTSTRAP_SERVERS'])
    props.put('group.id', @config['GROUP_ID'])
    props.put('key.deserializer', StringDeserializer.java_class.name)
    props.put('value.deserializer', StringDeserializer.java_class.name)
    props.put('auto.offset.reset', @config['AUTO_OFFSET_RESET'])
    props.put('enable.auto.commit', 'false')
    props.put('max.poll.records', @config['BATCH_SIZE'].to_s)
    
    # Otimizações de performance
    props.put('fetch.min.bytes', '50000')
    props.put('fetch.max.wait.ms', '500')
    props.put('max.partition.fetch.bytes', '1048576') # 1MB
    props.put('receive.buffer.bytes', '65536')        # 64KB
    props.put('send.buffer.bytes', '131072')          # 128KB

    @consumer = KafkaConsumer.new(props)
    @topic = @config['TOPIC']
    @poll_ms = @config['POLL_MS']
    @batch_buf = []
    
    # Pre-alocação para melhor performance
    @batch_buf.reserve(@config['BATCH_SIZE'])
    
    # Metrics
    @total_processed = 0
    @last_log_time = Time.now
    @last_processed_count = 0

    @consumer.subscribe(Arrays.asList(@topic))
    puts "✅ Kafka Consumer initialized successfully (JRuby Optimized)"
  end

  def start
    trap_signals

    loop do
      records = @consumer.poll(Duration.ofMillis(@poll_ms))
      next if records.isEmpty

      @batch_buf.clear
      parse_start = Time.now

      # Parse em batch com minimal allocations
      records.each do |record|
        begin
          payload = JSON.parse(record.value)
          @batch_buf << build_row_fast(payload)
        rescue JSON::ParserError => e
          LOGGER.error("JSON parse error: #{e.message}")
        rescue StandardError => e
          LOGGER.error("Processing error: #{e.message}")
        end
      end

      if @batch_buf.any?
        begin
          insert_start = Time.now
          
          # BULK INSERT usando insert_all (Rails 6+) ou fallback para SQL raw
          if KioskEvent.respond_to?(:insert_all)
            KioskEvent.insert_all(@batch_buf, returning: false)
          else
            bulk_insert_raw(@batch_buf)
          end
          
          @consumer.commitSync
          
          insert_time = Time.now - insert_start
          @total_processed += @batch_buf.size
          
          # Log periódico de performance
          log_performance(insert_time, @batch_buf.size)
          
        rescue StandardError => e
          LOGGER.error("Batch insert failed: #{e.message}")
          LOGGER.error(e.backtrace.join("\n"))
        end
      end
    end
  rescue Interrupt
    LOGGER.info('🛑 Interrompido (SIGINT). Encerrando…')
  ensure
    shutdown
  end

  private

  def build_row_fast(payload)
    # Versão otimizada com menos allocations
    now = Time.now.utc
    
    event_ts = nil
    if ts_raw = (payload['eventTs'] || payload[:eventTs])
      begin
        event_ts = Time.parse(ts_raw.to_s)
      rescue
        # ignore invalid timestamps
      end
    end

    event_type = "jruby-#{payload['eventType'] || payload[:eventType]}"

    {
      mall_id: payload['mallId'] || payload[:mallId],
      kiosk_id: payload['kioskId'] || payload[:kioskId],
      event_type: event_type,
      event_ts: event_ts,
      amount_cents: payload['amountCents'] || payload[:amountCents],
      total_items: payload['totalItems'] || payload[:totalItems],
      payment_method: payload['paymentMethod'] || payload[:paymentMethod],
      status: payload['status'] || payload[:status],
      created_at: now,
      updated_at: now
    }
  end

  def bulk_insert_raw(rows)
    return if rows.empty?
    
    # SQL bulk insert otimizado para PostgreSQL
    table_name = KioskEvent.table_name
    columns = rows.first.keys
    column_names = columns.map { |col| ActiveRecord::Base.connection.quote_column_name(col) }.join(', ')
    
    values_sql = rows.map do |row|
      values = columns.map { |col| ActiveRecord::Base.connection.quote(row[col]) }
      "(#{values.join(', ')})"
    end.join(', ')
    
    sql = "INSERT INTO #{table_name} (#{column_names}) VALUES #{values_sql}"
    ActiveRecord::Base.connection.execute(sql)
  end

  def log_performance(insert_time, batch_size)
    now = Time.now
    if now - @last_log_time >= 5 # Log a cada 5 segundos
      time_diff = now - @last_log_time
      new_processed = @total_processed - @last_processed_count
      rate = (new_processed / time_diff).round(2)
      
      LOGGER.info("🚀 Performance: #{rate} msgs/sec | Batch: #{batch_size} | Insert: #{(insert_time * 1000).round(2)}ms | Total: #{@total_processed}")
      
      @last_log_time = now
      @last_processed_count = @total_processed
    end
  end

  def trap_signals
    %w[INT TERM].each do |sig|
      Signal.trap(sig) do
        LOGGER.info("🛑 Recebido SIG#{sig}. Encerrando…")
        raise Interrupt
      end
    end
  end

  def shutdown
    LOGGER.info("📊 Final stats: #{@total_processed} mensagens processadas")
    
    begin
      @consumer&.wakeup
    rescue StandardError => e
      LOGGER.warn("Error waking up consumer: #{e.message}")
    end
    
    begin
      @consumer&.close
    rescue StandardError => e
      LOGGER.warn("Error closing consumer: #{e.message}")
    end
    
    LOGGER.info('👋 Consumer fechado.')
  end
end

BenchmarkConsumerJava.new.start