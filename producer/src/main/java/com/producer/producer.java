package com.producer;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.LocalDateTime;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class producer {
    private static KafkaProducer<String, String> kafkaProducer;
    
    public static void main(String[] args) {

        int numMessages = 1_000_000; // 1 milhão de mensagens
        String topicName = System.getenv().getOrDefault("TOPIC", "jobs");
        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:9092");

        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        kafkaProducer = new KafkaProducer<>(props);
        
        ExecutorService executor = Executors.newFixedThreadPool(32);
        System.out.println("[" + LocalDateTime.now() + "] Starting to produce " + numMessages + " messages to topic: " + topicName);        

        for (int i = 1; i <= numMessages; i++) {
            final LocalDateTime eventTime = LocalDateTime.now().minusDays(ThreadLocalRandom.current().nextLong(365));

            executor.submit(() -> {
                dispatchEvent(eventTime, "visit", topicName);
            });
        }
        
        executor.shutdown();

        try {
            executor.awaitTermination(120, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }

        kafkaProducer.flush();
        
        System.out.println("[" + LocalDateTime.now() + "] Finished producing " + numMessages + " messages with flush");

        System.out.println("[" + LocalDateTime.now() + "] Starting phase 2: 25k events every 15 minutes (individual messages, no flush)");
        
        Properties individualProps = new Properties();
        individualProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        individualProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        individualProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        
        LocalDateTime startTime = LocalDateTime.now();
        int eventCount = 0;
        
        while (true) {
            // Verifica se completou 15 minutos E se ainda há eventos para enviar no ciclo atual
            if (LocalDateTime.now().isAfter(startTime.plusMinutes(15))) {
                eventCount = 0;
                startTime = LocalDateTime.now();
                
                continue;
            }

            dispatchEventIndividual(LocalDateTime.now(), "purchase", topicName, bootstrapServers);
            eventCount++;

            try {
                Thread.sleep(36);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        kafkaProducer.close();
        System.out.println("[" + LocalDateTime.now() + "] Producer finished completely");
    }

    private static KioskEvent createKioskEvent(LocalDateTime eventTime, String eventType) {
        return new KioskEvent(
            1,
            1,
            0,
            eventType,
            eventTime.toString(),
            1000,
            5,
            1
        );
    }

    private static void dispatchEvent(LocalDateTime lastEventTime, String eventType, String topicName) {
        KioskEvent event = createKioskEvent(lastEventTime, eventType);
        ObjectMapper objectMapper = new ObjectMapper();

        try {
            String value = objectMapper.writeValueAsString(event);
            ProducerRecord<String, String> record = new ProducerRecord<>(topicName, String.valueOf(event.getKioskId()), value);
            kafkaProducer.send(record).get();
        } catch (JsonProcessingException | InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
    }

    private static void dispatchEventIndividual(LocalDateTime lastEventTime, String eventType, String topicName, String bootstrapServers) {
        KioskEvent event = createKioskEvent(lastEventTime, eventType);
        ObjectMapper objectMapper = new ObjectMapper();
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            String value = objectMapper.writeValueAsString(event);
            ProducerRecord<String, String> record = new ProducerRecord<>(topicName, String.valueOf(event.getKioskId()), value);
            producer.send(record).get();
        } catch (JsonProcessingException | InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
    }
}
