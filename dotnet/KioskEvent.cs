public record KioskEventDto(
    int mallId,
    int kioskId,
    string eventType,
    string eventTs,
    int amountCents,
    int totalItems,
    int paymentMethod,
    int status
);

public record KioskEvent(
    int Id = 0,
    int MallId = 0,
    int KioskId = 0,
    string EventType = "",
    DateTime EventTs = default,
    int AmountCents = 0,
    int TotalItems = 0,
    int PaymentMethod = 0,
    int Status = 0,
    DateTime CreatedAt = default,
    DateTime UpdatedAt = default
);
