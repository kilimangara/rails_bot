class Bundle < ApplicationRecord
  has_many :bundle_lines
  has_many :variants, through: :bundle_lines
end
