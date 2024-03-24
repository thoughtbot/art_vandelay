class User < ApplicationRecord
  validates :password, presence: true

  has_many :posts
end
