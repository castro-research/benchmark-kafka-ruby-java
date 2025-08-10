class BenchmarkConsumer < ApplicationConsumer
  def consume
    batch_size = ENV.fetch('BATCH_SIZE', '200').to_i

    messages.each_slice(batch_size) do |batch|
      process_batch(batch)
    end
  end

  private

  def process_batch(batch)
    puts "Processando #{batch.size} mensagens"
  end
end
