# Cenário

Uma empresa possui diversos totens de autoatendimento, e cada totem envia mensagens para um tópico Kafka. Essas mensagens são processadas por um job que popula um banco de dados Postgres.

A cada 15 minutos, cada totem envia cerca de 25 mensagens. Em um shopping, há cerca de 10 totens, então a cada 15 minutos temos aproximadamente 250 mensagens para processar.

A empresa possui 100 shoppings, então a cada 15 minutos temos cerca de 25.000 mensagens para processar, totalizando aproximadamente 100.000 mensagens por hora.

Por algum motivo, o serviço caiu por 10 horas, e as mensagens não foram processadas. Agora, o serviço foi reiniciado e está tentando processar todas as mensagens acumuladas.

Temos 1 milhão de mensagens para processar, quanto tempo levará para processar todas essas mensagens?

Eu vou tentar responder as seguintes perguntas:

- Qual é o Bottleneck? 
- O que podemos fazer para melhorar o desempenho? 

# Pendências

- [x] Comunicar Kafka, Postgres e Rails
- [x] Criar um producer de teste para enviar mensagens ao Kafka
- [x] Criar um consumer de teste com Ruby (usando MRI) para consumir mensagens do Kafka
- [x] Montar um payload para popular o banco de dados Postgres
- [x] Criar um job que consome as mensagens com o payload do cenário
- [x] Consumir os 1 milhão de mensagens do Kafka e popular o banco de dados Postgres
- [x] Limitar hardware virtual do container para ser mais justo
- [x] Após enviar 1 milhão de mensagens, continuar produzindo mensagens continuamente
- [ ] Fazer cálculos mais pesados no job ou fazer I/O mais pesado
- [ ] Paralelizar o processamento de mensagens
- [ ] Planejar e criar um benchmark para medir o tempo de processamento

# Preparação do ambiente

Primeiro, os parametros do Postgres não terão nenhum ajuste de desempenho.

No Kafka, nosso tópico terá as seguintes configurações padrões:

| Configuração         | Valor padrão (`ENV`) | Descrição                              | O que significa?           |
|----------------------|----------------------|----------------------------------------|----------------------------|
| partitions           | 12                   | Número de partições                    | 12 partições               |
| replication_factor   | 1                    | Fator de replicação                    | 1 cópia                    |
| cleanup.policy       | compact              | Política de limpeza                    | Compactar dados            |
| retention.ms         | 604800000            | Retenção em milissegundos              | 7 dias                     |
| segment.bytes        | 1073741824           | Tamanho do segmento (bytes)            | 1 GB                       |
| max.message.bytes    | 20971520             | Tamanho máx. da mensagem (bytes)       | 20 MB                      |
| compression.type     | gzip                 | Tipo de compressão                     | GZIP                       |
| max.poll.records     | 1000                 | Máximo de registros por poll           | 1000 registros             |
| batch.size           | 200                  | Tamanho do lote                        | 200 mensagens              |


Sabendo que nosso maior vilão será I/O, vamos adicionar conexão de dados persistente ao Postgres.

Imagina que temos 1 milhão de mensagens para processar, e cada mensagem é um JSON que vai popular o banco.

# Iniciar Benchmark

## MRI (Rails)
 
```bash
docker-compose up kafka kafka-ui postgres producer setup mri --build
```


## MRI sem Rails e com Active record

```bash
docker-compose up kafka kafka-ui postgres producer mri-ar --build
```


## MRI sem Rails e sem Active record

```bash
docker-compose up kafka kafka-ui postgres producer mri-pg --build
```

## Truffleruby sem Active record

```bash
docker-compose up kafka kafka-ui postgres producer truffleruby-pg --build
```

## Truffleruby com Active record

```bash
docker-compose up kafka kafka-ui postgres producer truffleruby-ar --build
```

## Dotnet 9

```bash
docker-compose up kafka kafka-ui postgres producer truffleruby-ar --build
```

# Dicas

se quiser entrar no container do Rails, use:

```bash
docker compose run --rm -it console bash
```

Escalar workers:

```
docker compose --profile worker up -d --scale mri-worker=12
```


## Usando o Swarm

```
docker swarm init
docker stack deploy -c docker-compose.yml benchmark
```

Escalar os consumers do Swarm:

```bash
docker service scale benchmark_mri-worker=12
```

# Resultados

Vou separar os resultados por teste, e cada teste terá um número de relevância de 0 a 10, onde 0 é irrelevante e 10 é extremamente relevante.

As ferramentas utilizadas para os testes serão:

- Ruby 3.3.X (MRI)
- Java 21 (OpenJDK)
- Rails 8
- postgres:17
- Apache Kafka
- Kafka UI
- DBeaver
- .NET 9
- [Kafka Flow](https://farfetch.github.io/kafkaflow/docs/getting-started/create-your-first-application)

![Test 001 Results](.github/1.png)

Todos resultados serão apresentados em ([`report.md`](report.md))

## Resultados relevantes


## Conclusões


# Referências

- [PostgreSQL Documentation: Populating a Database](https://www.postgresql.org/docs/current/populate.html)

- [Speeding Up PostgreSQL Inserts](https://stackoverflow.com/questions/12206600/how-to-speed-up-insertion-performance-in-postgresql)

- [Optimizing for Fast Testing](https://stackoverflow.com/questions/9407442/optimise-postgresql-for-fast-testing/9407940#9407940/)
