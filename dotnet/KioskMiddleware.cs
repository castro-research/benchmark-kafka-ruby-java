using System.Text;
using System.Text.Json;
using System.Globalization;
using KafkaFlow;
using Microsoft.EntityFrameworkCore;

public sealed class PersistKioskEventsMiddleware : IMessageMiddleware
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public PersistKioskEventsMiddleware(IDbContextFactory<AppDbContext> dbFactory)
        => _dbFactory = dbFactory;

    public async Task Invoke(IMessageContext context, MiddlewareDelegate next)
    {
        
        var batch = context.GetMessagesBatch();

        var now = DateTime.UtcNow;
        var toInsert = new List<KioskEvent>();

        foreach (var msgCtx in batch)
        {
            try
            {
                var kioskEvent = ParseMessage(msgCtx, now);
                if (kioskEvent != null)
                {
                    toInsert.Add(kioskEvent);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error processing message: {ex.Message}");
            }
        }

        if (toInsert.Any())
        {
            await SaveEvents(toInsert);
        }

        await next(context);
    }

    private KioskEvent? ParseMessage(IMessageContext msgCtx, DateTime now)
    {
        
        string json;
        if (msgCtx.Message.Value is byte[] bytes)
        {
            json = Encoding.UTF8.GetString(bytes);
        }
        else if (msgCtx.Message.Value is string str)
        {
            json = str;
        }
        else
        {
            return null;
        }

        var dto = JsonSerializer.Deserialize<KioskEventDto>(json, JsonOpts);
        if (dto == null)
        {
            return null;
        }

        
        if (!TryParseEventTimestamp(dto.eventTs, out var eventTsUtc))
        {
            return null;
        }

        return new KioskEvent(
            0,
            dto.mallId,
            dto.kioskId,
            $"dotnet_{dto.eventType}",
            eventTsUtc,
            dto.amountCents,
            dto.totalItems,
            dto.paymentMethod,
            dto.status,
            now,
            now
        );
    }

    private static bool TryParseEventTimestamp(string eventTs, out DateTime eventTsUtc)
    {
        var formats = new[]
        {
            "yyyy-MM-ddTHH:mm:ss.fffffffZ",
            "yyyy-MM-ddTHH:mm:ss.fffZ",
            "yyyy-MM-ddTHH:mm:ssZ",
            "yyyy-MM-ddTHH:mm:ss.fffffff",
            "yyyy-MM-ddTHH:mm:ss.fff",
            "yyyy-MM-ddTHH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
        };

        foreach (var format in formats)
        {
            if (DateTime.TryParseExact(eventTs, format, null, DateTimeStyles.AssumeUniversal, out eventTsUtc))
            {
                eventTsUtc = DateTime.SpecifyKind(eventTsUtc, DateTimeKind.Utc);
                return true;
            }
        }

        if (DateTime.TryParse(eventTs, out var parsed))
        {
            eventTsUtc = DateTime.SpecifyKind(parsed, DateTimeKind.Utc);
            return true;
        }

        eventTsUtc = default;
        return false;
    }

    private async Task SaveEvents(IEnumerable<KioskEvent> events)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        
        db.ChangeTracker.AutoDetectChangesEnabled = false;
        
        await using var tx = await db.Database.BeginTransactionAsync();
        try
        {
            db.KioskEvents.AddRange(events);
            await db.SaveChangesAsync();
            await tx.CommitAsync();
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}