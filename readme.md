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
- [ ] Após enviaar 1 milhão de mensagens, continuar produzindo mensagens continuamente
- [ ] Fazer cálculos mais pesados no job ou fazer I/O mais pesado
- [ ] Paralelizar o processamento de mensagens
- [ ] Planejar e criar um benchmark para medir o tempo de processamento

# Preparação do ambiente

Primeiro, os parametros do Postgres não terão nenhum ajuste de desempenho.

No Kafka, nosso tópico terá as seguintes configurações padrões:

| Configuração         | Valor padrão (`ENV`) | Descrição                              | O que significa?           |
|----------------------|----------------------|----------------------------------------|----------------------------|
| partitions           | 4                    | Número de partições                    | 4 partições                |
| replication_factor   | 1                    | Fator de replicação                    | 1 cópia                    |
| cleanup.policy       | delete               | Política de limpeza                    | Excluir dados antigos      |
| retention.ms         | 3600000              | Retenção em milissegundos              | 1 hora                     |
| segment.bytes        | 134217728            | Tamanho do segmento (bytes)            | 128 MB                     |
| max.message.bytes    | 1048576              | Tamanho máx. da mensagem (bytes)       | 1 MB                       |
| compression.type     | producer             | Tipo de compressão                     | Definido pelo produtor     |


Sabendo que nosso maior vilão será I/O, vamos adicionar conexão de dados persistente ao Postgres.

Imagina que temos 1 milhão de mensagens para processar, e cada mensagem é um JSON que vai popular o banco.


# Iniciar Benchmark

```bash
docker-compose up --build
```


### Dicas

se quiser entrar no container do Rails, use:

```bash
docker compose run --rm -it console bash
```