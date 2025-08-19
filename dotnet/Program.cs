using Confluent.Kafka;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using static KioskEvent;
using static AppDbContext;
using System.Globalization;

var config = new ConsumerConfig
{
    BootstrapServers = "kafka:29092",
    GroupId = "test-consumer-group",
    AutoOffsetReset = AutoOffsetReset.Earliest,
    EnableAutoCommit = false
};


using var consumer = new ConsumerBuilder<Ignore, string>(config).Build();
consumer.Subscribe("jobs");

var cancellationToken = CancellationToken.None;

// Build configuration to pass to AppDbContext
var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile($"appsettings.Development.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables()
    .Build();

await using var context = new AppDbContext(configuration);
Console.WriteLine("Starting to consume messages...");

while (!cancellationToken.IsCancellationRequested)
{
    var consumeResult = consumer.Consume(cancellationToken);
    var messageJson = JsonSerializer.Deserialize<JsonElement>(consumeResult.Message.Value);
    var eventType = messageJson.GetProperty("eventType").GetString();
    var modifiedEventType = $"dotnet_{eventType}";
    var eventTsString = messageJson.GetProperty("eventTs").GetString()!;
    var eventTs = DateTime.Parse(eventTsString).ToUniversalTime();


    var kioskEvent = new KioskEvent(
        0,
        messageJson.GetProperty("mallId").GetInt32(),
        messageJson.GetProperty("kioskId").GetInt32(),
        modifiedEventType,
        eventTs,
        messageJson.GetProperty("amountCents").GetInt32(),
        messageJson.GetProperty("totalItems").GetInt32(),
        messageJson.GetProperty("paymentMethod").GetInt32(),
        messageJson.GetProperty("status").GetInt32()
    );

    context.KioskEvents.Add(kioskEvent);
    await context.SaveChangesAsync();

    // Libera memória
    context.ChangeTracker.Clear();
    consumer.Commit(consumeResult);
}
consumer.Close();
