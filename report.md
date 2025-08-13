# Resultados

Vou separar os resultados por teste, e cada teste terá um número de relevância de 0 a 10, onde 0 é irrelevante e 10 é extremamente relevante.

### Teste#001

```
Relevância: 0
Observações:
Sem paralelização, sem otimizações, sem ajustes de hardware, sem limitações de CPU e RAM. ( Usando Macbook M4 Max e 36GB RAM )
Só receber dados e inserir no banco de dados.

Resultados:
Inicio: 2025-08-12 18:46:53.835
Fim: 2025-08-12 18:54:02.651
Total processado: 1.000.000 eventos
Tempo total: 7 minutos
Média de mensagens por segundo: 2.380,95 (1.000.000 eventos / 420 segundos)
Média de tempo por mensagem: 0,42 ms (420 segundos / 1.000.000 eventos)
```

### Teste#002

```
Relevância: 2
Observações:
Sem paralelização, sem otimizações, sem ajustes de hardware, com limitações de 2 CPUs e 2 GB de RAM.
ainda faltam 600.000 eventos, e ja acumula um pouco mais de 900.000 eventos no banco de dados.

Resultados:
Inicio: 2025-08-13 17:30:44.958
Fim: 2025-08-13 18:00:23.154
Total processado: 400.000 eventos
Tempo total: 29 minutos
Média de mensagens por segundo: 229,41 (400.000 eventos / 1.742 segundos)
Média de tempo por mensagem: 4,31 ms (1.742 segundos / 400.000 eventos)
```

### Teste#003

Até agora, eu tinha 1 partição, 1 consumer, e 1 producer. 

Me questiono: Aumentar partições para 12 ajuda em que ? Nada! Só se eu tivesse mais consumers.

Neste momento, vamos fazer duas otimizações:
1. Aumentar o tamanho do lote de mensagens para 2000.
2. Mudar o tipo de compressão do tópico de `none` para `gzip`.
3. Usar thread pool no producer para enviar mensagens em paralelo. ( Não tem a ver com consumer em si )

Não estamos preocupado neste momento com tamanho de mensagem, apenas com o fluxo, que não está levando a CPU acima de 20% ( Mesmo com limitação ).

Uma das otimizações é mudar o compression.type do tópido de `none` por (lz4)[https://stackoverflow.com/questions/67537111/how-do-i-decide-between-lz4-and-snappy-compression] para ganhar performance de descompressão.

Já que no Karafka, (o default é none)[https://karafka.io/docs/Librdkafka-Configuration/#global-configuration-properties].

| Property | Required | Valid Values | Default | Priority | Description |
|----------|----------|--------------|---------|----------|-------------|
| compression.type | P | none, gzip, snappy, lz4, zstd | none | medium | Alias for compression.codec: compression codec to use for compressing message sets. This is the default value for all topics, may be overridden by the topic configuration property compression.codec. Type: enum value |

A parte do thread pool é interessante, pois ele tava fazendo flush por cada messagem enviada, e no fim, eu tinha picos baixos de CPU, por que as mensagens não tinha sido commited ainda. 

Então eu tinha mais tempo ocioso, e o teste precisa ter em conta que tenho 1 milhão de mensagem pendente.

```bash
[2025-08-13T19:22:16.573964638] Starting to produce 1000000 messages to topic: jobs
[2025-08-13T19:22:40.645495927] Finished producing 1000000 messages with flush in 0ms
```

Essa mudança no producer é loucura, de tão rápido.

```
Relevância: 8
Observações:

Resultados:
Inicio: 2025-08-13 19:22:17.361
Fim: 2025-08-13 19:29:15.891
Total processado: 1.000.000 eventos
Tempo total: 6 minutos
Média de mensagens por segundo: 2.777,78 (1.000.000 eventos / 360 segundos)
Média de tempo por mensagem: 0,36 ms (360 segundos / 1.000.000 eventos)
```

### Teste#004

A mudança brusca do Teste#003 me fez questionar uma coisa:

Será que eu perco performance se eu estou fazendo leitura e escrita na mesma partição ?

Então preciso ao mesmo tempo escrever de forma contínua, como se além dos 1 milhão, eu continuasse recebendo eventos.


```
Relevância: 8
Observações:
Aparentemente, o resultado é o mesmo. o pull vai ser menor, por que eu pego exatamente o que está disponível na partição.

Resultados:
Inicio: 2025-08-13 19:53:00.584
Fim: 2025-08-13 19:59:25.848
Total processado: 1.000.000 eventos
Tempo total: 6 minutos
Média de mensagens por segundo: 2.777,78 (1.000.000 eventos / 360 segundos)
Média de tempo por mensagem:  0,36 ms (360 segundos / 1.000.000 eventos)
```

![Test Results](.github/2.png)

### Teste#005

O resultado do Teste#003, e o Teste#004, sem precisar de otimizar o consumer, me faz pensar que está muito fácil.

Agora é a hora de deixar o consumer mais lento, antes de otimizar ele.

[Work in progress....]