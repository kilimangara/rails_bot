class Product < ApplicationRecord
  after_create :create_variant

  has_and_belongs_to_many :categories

  has_attached_file :image
  do_not_validate_attachment_file_type :image

  has_many :variants

  private

  def create_variant
    Variant.create(product_id: id, name: name, price: price)
  end

  def s3_credentials
    { bucket: 'statictgbot', access_key_id: 'AKIAIGPYEROJQ4RT75SA', secret_access_key: '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' }
  end
end
