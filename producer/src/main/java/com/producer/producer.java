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

public class producer {
    public static void main(String[] args) {
        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:9092");
        String topicName = System.getenv().getOrDefault("TOPIC", "jobs");

        int numMessages = 1_000_000_000;
        LocalDateTime lastEventTime = LocalDateTime.now();

        // Configurações do producer
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            for (int i = 1; i <= numMessages; i++) {
                String key = "key-" + i;
                KioskEvent event = new KioskEvent(
                        1, // mallId
                        1, // kioskId
                        0, // status (0: pending)
                        "eventType-" + i, // eventType
                        lastEventTime.toString(), // eventTs
                        1000, // amountCents
                        5, // totalItems
                        1 // paymentMethod
                );

                ObjectMapper objectMapper = new ObjectMapper();
                String value;
                try {
                    value = objectMapper.writeValueAsString(event);
                    ProducerRecord<String, String> record = new ProducerRecord<>(topicName, key, value);
                    producer.send(record).get();
                } catch (JsonProcessingException e) {
                    e.printStackTrace();
                }

                // Atualiza o timestamp para trás
                lastEventTime = lastEventTime.minusMinutes((long) (10 + Math.random() * 5));
            }
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
    }
}
