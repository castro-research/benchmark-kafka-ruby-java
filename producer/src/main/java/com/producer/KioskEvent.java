package com.producer;

public class KioskEvent {
    int mallId;
    int kioskId;
    String eventType;
    String eventTs;
    int amountCents;
    int totalItems;
    int paymentMethod;
    int status = 0; // 0: pending, 1: completed, 2: failed

    public KioskEvent(int mallId, int kioskId, int status, String eventType, String eventTs, int amountCents, int totalItems, int paymentMethod) {
        this.mallId = mallId;
        this.kioskId = kioskId;
        this.status = status;
        this.eventType = eventType;
        this.eventTs = eventTs;
        this.amountCents = amountCents;
        this.totalItems = totalItems;
        this.paymentMethod = paymentMethod;
    }

    public int getMallId() {
        return mallId;
    }

    public int getKioskId() {
        return kioskId;
    }

    public String getEventType() {
        return eventType;
    }

    public String getEventTs() {
        return eventTs;
    }

    public int getAmountCents() {
        return amountCents;
    }

    public int getTotalItems() {
        return totalItems;
    }

    public int getPaymentMethod() {
        return paymentMethod;
    }

    public int getStatus() {
        return status;
    }
}
