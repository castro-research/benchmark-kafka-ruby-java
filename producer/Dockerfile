FROM maven:3.9.9-eclipse-temurin-24 AS build
WORKDIR /app
COPY pom.xml .

RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:24-jre
WORKDIR /app
COPY --from=build /app/target/kafka-producer-1.0-SNAPSHOT.jar /app/app.jar

# Variáveis padrão
ENV BOOTSTRAP_SERVERS=kafka:9092
ENV TOPIC=jobs
ENV MSGS=10

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
