class BenchmarkConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      begin
        process_message(message)
      rescue StandardError => e
        Rails.logger.error("Failed to process message: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end

  private

  def process_message(message)
    begin
      payload = message.payload
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse message payload: #{e.message}")
      Rails.logger.error("Raw message: #{message.raw_payload}")
      return
    end
    
    event_ts = Time.parse(payload['eventTs']) rescue nil

    KioskEvent.create!(
      mall_id: payload['mallId'],
      kiosk_id: payload['kioskId'],
      event_type: payload['eventType'],
      event_ts: event_ts,
      amount_cents: payload['amountCents'],
      total_items: payload['totalItems'],
      payment_method: payload['paymentMethod'],
      status: payload['status'] || payload[:status]
    )
  end
end
