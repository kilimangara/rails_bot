class Product < ApplicationRecord

  after_create :create_variant

  has_and_belongs_to_many :categories

  has_many :variants

  private

  def create_variant
    Variant.create(product_id: id, name: name, price: price)
  end
end
