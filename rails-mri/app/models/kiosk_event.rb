class KioskEvent < ApplicationRecord
    enum :status, {
      pending: 0,
      completed: 1,
      failed: 2
    }
end
