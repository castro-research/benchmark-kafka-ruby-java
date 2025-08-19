# frozen_string_literal: true

class KarafkaApp < Karafka::App
  BATCH_SIZE = 2000
  PARTITIONS = 1
  REPLICATION_FACTOR = 1 # Sem replicação para simplificar o ambiente
  CLEANUP_POLICY = 'compact' # compact or delete
  RETENTION_MS = 604800000 # 7 days
  SEGMENT_BYTES = 1073741824 # 1 GB
  MAX_MESSAGE_BYTES = 20971520 # 20 MB
  MAX_PARTITION_FETCH_BYTES = 20971520 # 20 MB
  FETCH_MAX_BYTES = 52428800 # 50 MB
  COMPRESSION_TYPE = 'gzip'

  setup do |config|
    config.kafka = { 
      'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'kafka:9092'),
      # 'max.partition.fetch.bytes': MAX_PARTITION_FETCH_BYTES,
      # 'fetch.max.bytes': FETCH_MAX_BYTES,
    }

    config.client_id = 'benchmark'
    config.max_messages = BATCH_SIZE

    # IMPORTANT: Customize this group_id with your application name.
    # The group_id should be unique per application to properly track message consumption.
    # Example: config.group_id = 'inventory_service_consumer'
    #
    # Note: Advanced features and custom routing configurations may define their own consumer
    # groups. These should also be uniquely named per application to avoid conflicts.
    # For the advanced features, subscription groups and consumer groups in your routing
    # configuration, follow the same uniqueness principle.
    #
    # For more details on consumer groups and routing configuration, please refer to the
    # Karafka documentation: https://karafka.io/docs
    config.group_id = ENV.fetch('KARAFKA_GROUP_ID', 'g1')
    # Recreate consumers with each batch. This will allow Rails code reload to work in the
    # development mode. Otherwise Karafka process would not be aware of code changes
    config.consumer_persistence = !Rails.env.development?
  end

  # Comment out this part if you are not using instrumentation and/or you are not
  # interested in logging events for certain environments. Since instrumentation
  # notifications add extra boilerplate, if you want to achieve max performance,
  # listen to only what you really need for given environment.
  Karafka.monitor.subscribe(
    Karafka::Instrumentation::LoggerListener.new(
      # Karafka, when the logger is set to info, produces logs each time it polls data from an
      # internal messages queue. This can be extensive, so you can turn it off by setting below
      # to false.
      log_polling: true
    )
  )
  # Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  # This logger prints the producer development info using the Karafka logger.
  # It is similar to the consumer logger listener but producer oriented.
  Karafka.producer.monitor.subscribe(
    WaterDrop::Instrumentation::LoggerListener.new(
      # Log producer operations using the Karafka logger
      Karafka.logger,
      # If you set this to true, logs will contain each message details
      # Please note, that this can be extensive
      log_messages: false
    )
  )

  # You can subscribe to all consumer related errors and record/track them that way
  #
  # Karafka.monitor.subscribe 'error.occurred' do |event|
  #   type = event[:type]
  #   error = event[:error]
  #   details = (error.backtrace || []).join("\n")
  #   ErrorTracker.send_error(error, type, details)
  # end

  # You can subscribe to all producer related errors and record/track them that way
  # Please note, that producer and consumer have their own notifications pipeline so you need to
  # setup error tracking independently for each of them
  #
  # Karafka.producer.monitor.subscribe('error.occurred') do |event|
  #   type = event[:type]
  #   error = event[:error]
  #   details = (error.backtrace || []).join("\n")
  #   ErrorTracker.send_error(error, type, details)
  # end

  routes.draw do
   active_job_topic :default if ENV['USE_ACTIVE_JOB'] == '1'

  consumer_group :g1 do    
    topic :jobs do
      config(
        partitions: PARTITIONS,
        # replication_factor:  REPLICATION_FACTOR,
        # 'cleanup.policy':    CLEANUP_POLICY,
        # 'retention.ms':      RETENTION_MS,
        # 'segment.bytes':     SEGMENT_BYTES,
        # 'max.message.bytes': MAX_MESSAGE_BYTES,
        # 'compression.type':  COMPRESSION_TYPE,
      )

      consumer BenchmarkConsumer
      end
    end
  end
end

# Karafka now features a Web UI!
# Visit the setup documentation to get started and enhance your experience.
#
# https://karafka.io/docs/Web-UI-Getting-Started
