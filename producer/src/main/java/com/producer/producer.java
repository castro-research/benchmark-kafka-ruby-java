package com.producer;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Properties;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class producer {
    private static final int INITIAL_MESSAGES = 50_000_000;
    private static final int BATCH_SIZE = 100_000;
    private static final int THREADS = 32;
    private static final int INITIAL_AWAIT_SECONDS = 120;
    private static final int BATCH_AWAIT_SECONDS = 60;

    private static final AtomicLong GLOBAL_SEQ = new AtomicLong(0);

    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static void main(String[] args) {

        final String topic = System.getenv().getOrDefault("TOPIC", "jobs");
        final String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:9092");

        System.out.printf("[%s] Starting to produce %,d messages to topic: %s%n",
                LocalDateTime.now(), INITIAL_MESSAGES, topic);

        // Comentar essa parte para o Teste#006
        // Inicio
        try (KafkaProducer<String, String> producer = createProducer(bootstrapServers)) {
            produceFixedMessages(producer, topic, INITIAL_MESSAGES, THREADS, INITIAL_AWAIT_SECONDS);
            producer.flush();
        }
        // Fim

        System.out.printf("[%s] Finished producing %,d messages with flush%n",
                LocalDateTime.now(), INITIAL_MESSAGES);

        System.out.printf("[%s] Starting phase 2: %,d events every minute with flush%n",
                LocalDateTime.now(), BATCH_SIZE);

        try (KafkaProducer<String, String> producer = createProducer(bootstrapServers)) {
            produceRecurringBatches(producer, topic, BATCH_SIZE, THREADS, Duration.ofSeconds(10));
        }
    }

    private static KafkaProducer<String, String> createProducer(String bootstrapServers) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "1");
        props.put(ProducerConfig.LINGER_MS_CONFIG, "5");
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, String.valueOf(64 * 1024));
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");
        return new KafkaProducer<>(props);
    }

    private static void produceFixedMessages(KafkaProducer<String, String> producer,
                                             String topic,
                                             int totalMessages,
                                             int threads,
                                             int awaitSeconds) {
        ExecutorService exec = Executors.newFixedThreadPool(threads);
        for (int i = 0; i < totalMessages; i++) {
            exec.submit(() -> sendNextEvent(producer, topic, "visit"));
        }
        shutdownAndAwait(exec, awaitSeconds);
    }

    private static void produceRecurringBatches(KafkaProducer<String, String> producer,
                                                String topic,
                                                int batchSize,
                                                int threads,
                                                Duration period) {
        int cycle = 0;
        while (true) {
            // Esta seção é para o Teste#007 
            if(cycle == 10) {
                System.out.printf("[%s] Stopping after 10 cycles%n", LocalDateTime.now());
                break;
            }
            // Fim
            
            LocalDateTime batchStart = LocalDateTime.now();
            System.out.printf("[%s] Starting batch of %,d events%n", batchStart, batchSize);

            ExecutorService exec = Executors.newFixedThreadPool(threads);
            for (int i = 0; i < batchSize; i++) {
                exec.submit(() -> sendNextEvent(producer, topic, "purchase"));
            }
            shutdownAndAwait(exec, BATCH_AWAIT_SECONDS);

            producer.flush();
            cycle++;

            LocalDateTime batchEnd = LocalDateTime.now();
            System.out.printf("[%s] Completed batch of %,d events with flush%n", batchEnd, batchSize);

            long elapsed = Duration.between(batchStart, LocalDateTime.now()).getSeconds();
            long sleepSeconds = Math.max(0, period.getSeconds() - elapsed);
            if (sleepSeconds > 0) {
                System.out.printf("[%s] Waiting %d seconds until next batch%n", LocalDateTime.now(), sleepSeconds);
                sleepQuietly(Duration.ofSeconds(sleepSeconds));
            }
        }
    }

    private static void sendNextEvent(KafkaProducer<String, String> producer, String topic, String baseEventType) {
        long seq = GLOBAL_SEQ.getAndIncrement();
        int kioskId = (int) (seq / 100_000L); // incrementa a cada 100_000 eventos
        LocalDateTime eventTime = LocalDateTime.now().minusDays(ThreadLocalRandom.current().nextLong(365));

        String finalEventType = baseEventType.equals("purchase")
                ? "purchase-" + kioskId
                : baseEventType;

        KioskEvent event = createKioskEvent(kioskId, eventTime, finalEventType);
        sendEvent(producer, topic, String.valueOf(kioskId), event);
    }

    private static void sendEvent(KafkaProducer<String, String> producer,
                                  String topic,
                                  String key,
                                  KioskEvent event) {
        try {
            String value = MAPPER.writeValueAsString(event);
            ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, value);
            producer.send(record, (metadata, ex) -> {
                if (ex != null) {
                    ex.printStackTrace();
                }
            });
        } catch (JsonProcessingException e) {
            e.printStackTrace();
        }
    }

    private static KioskEvent createKioskEvent(int kioskId, LocalDateTime eventTime, String eventType) {
        return new KioskEvent(1, kioskId, 0, eventType, eventTime.toString(), 1000, 5, 1);
    }

    private static void shutdownAndAwait(ExecutorService exec, int seconds) {
        exec.shutdown();
        try {
            if (!exec.awaitTermination(seconds, TimeUnit.SECONDS)) {
                exec.shutdownNow();
            }
        } catch (InterruptedException e) {
            exec.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }

    private static void sleepQuietly(Duration d) {
        try {
            Thread.sleep(d.toMillis());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
