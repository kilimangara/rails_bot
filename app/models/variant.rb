class Variant < ApplicationRecord

  belongs_to :product

  has_many :bundle_lines
  has_many :bundles, through: :bundle_lines
end
