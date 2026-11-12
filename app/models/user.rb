class User < ApplicationRecord
  DEMO_PUBLIC_ID = "shopper-7f3a9c2e41d8".freeze

  validates :public_id, presence: true, uniqueness: true
  validates :display_name, presence: true

  def self.demo
    find_by(public_id: DEMO_PUBLIC_ID)
  end
end
