package com.producer;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;
import java.util.concurrent.ExecutionException;

public class producer {
    public static void main(String[] args) {
        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:9092");
        String topicName = System.getenv().getOrDefault("TOPIC", "jobs");
        
        // TODO: Move to 1_000_000_000 messages when i finish the setup
        // int numMessages = 1_000_000_000; 
        int numMessages = 10;

        // Configurações do producer
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            for (int i = 1; i <= numMessages; i++) {
                String key = "key-" + i;
                String value = "Mensagem número " + i;

                ProducerRecord<String, String> record = new ProducerRecord<>(topicName, key, value);

                // Envia de forma síncrona (para garantir a ordem no exemplo)
                RecordMetadata metadata = producer.send(record).get();

                System.out.printf("Enviado: key=%s value=%s para %s-%d offset=%d%n",
                        key, value, metadata.topic(), metadata.partition(), metadata.offset());
            }
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
    }
}
