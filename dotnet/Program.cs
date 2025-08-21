using KafkaFlow;
using KafkaFlow.Serializer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Text.Json;

const string Topic = "jobs";

var builder = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
       
        services.AddDbContextFactory<AppDbContext>(options =>
            options.UseNpgsql(
                Environment.GetEnvironmentVariable("DATABASE_URL")
                ?? "Host=postgres;Username=bench;Password=bench;Database=bench"
            )
        );
       
        services.AddTransient<PersistKioskEventsMiddleware>();
       
        services.AddKafka(kafka => kafka
            .UseConsoleLog()
            .AddCluster(cluster => cluster
                .WithBrokers(new[] { "kafka:29092" })
                .AddConsumer(consumer => consumer
                    .Topic(Topic)
                    .WithGroupId("test-consumer-group")
                    .WithBufferSize(2000)
                    .WithWorkersCount(10)
                    .AddMiddlewares(middlewares => middlewares
                        .AddBatching(2000, TimeSpan.FromSeconds(1))
                        .Add<PersistKioskEventsMiddleware>() 
                    )
                )
                .AddProducer("producer-name", producer => producer
                    .DefaultTopic(Topic)
                    .AddMiddlewares(middlewares => middlewares 
                        .AddSerializer<JsonCoreSerializer>() 
                    )
                )
            )
        );
    });

var host = builder.Build();

// Handle graceful shutdown
using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => {
    e.Cancel = true;
    cts.Cancel();
};

var bus = host.Services.CreateKafkaBus();

await bus.StartAsync();
Console.WriteLine("✅ KafkaFlow consumer running. Press Ctrl+C to stop...");

try
{
    await Task.Delay(Timeout.Infinite, cts.Token);
}
catch (OperationCanceledException)
{
    Console.WriteLine("🛑 Shutdown signal received...");
}

await bus.StopAsync();