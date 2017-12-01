class Category < ApplicationRecord

  has_and_belongs_to_many :products

  belongs_to :parent_category, class_name: 'Category'

  has_many :inner_categories, class_name: 'Category', foreign_key: 'parent_category_id'
end
