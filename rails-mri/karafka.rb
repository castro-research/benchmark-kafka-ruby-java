# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', 'kafka:9092') }
    config.client_id = 'benchmark'

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

  consumer_group ENV.fetch('KARAFKA_GROUP_ID', 'g1').to_sym do
    topic ENV.fetch('TOPIC', 'jobs') do
      config(
        partitions:          Integer(ENV.fetch('PARTITIONS', '4')),
        replication_factor:  Integer(ENV.fetch('REPLICATION_FACTOR', '1')),
        'cleanup.policy':    ENV.fetch('CLEANUP_POLICY', 'delete'),
        'retention.ms':      Integer(ENV.fetch('RETENTION_MS', '3600000')),
        'segment.bytes':     Integer(ENV.fetch('SEGMENT_BYTES', '134217728')),
        'max.message.bytes': Integer(ENV.fetch('MAX_MESSAGE_BYTES', '1048576')),
        'compression.type':  ENV.fetch('COMPRESSION_TYPE', 'producer')
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
