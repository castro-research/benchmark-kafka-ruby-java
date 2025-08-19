public record KioskEvent(
    int Id,
    int MallId,
    int KioskId,
    string EventType,
    DateTime EventTs,
    int AmountCents,
    int TotalItems,
    int PaymentMethod,
    int Status
);
