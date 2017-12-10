class BundleLine < ApplicationRecord
  belongs_to :variant
  belongs_to :bundle
end
