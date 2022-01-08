class Sound < ApplicationRecord
  validates :name, :file, presence: true
  validates_uniqueness_of :name
end
