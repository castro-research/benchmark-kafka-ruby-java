using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using static KioskEvent;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<KioskEvent> KioskEvents { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Não se preocupe com a marreta :)
        modelBuilder.Entity<KioskEvent>(entity =>
        {
            entity.ToTable("kiosk_events");
            entity.HasKey(e => e.Id);
            
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.MallId).HasColumnName("mall_id");
            entity.Property(e => e.KioskId).HasColumnName("kiosk_id");
            entity.Property(e => e.EventType).HasColumnName("event_type");
            entity.Property(e => e.EventTs).HasColumnName("event_ts");
            entity.Property(e => e.AmountCents).HasColumnName("amount_cents");
            entity.Property(e => e.TotalItems).HasColumnName("total_items");
            entity.Property(e => e.PaymentMethod).HasColumnName("payment_method");
            entity.Property(e => e.Status).HasColumnName("status");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");
        });
    }
}