class User < ApplicationRecord
  validates :password, presence: true
end
