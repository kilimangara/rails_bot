class StackedOrderPlace < ApplicationRecord

  validates_presence_of :address

  validates_uniqueness_of :address

end
