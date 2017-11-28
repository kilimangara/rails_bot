class Product < ApplicationRecord

  has_and_belongs_to_many :categories

  has_and_belongs_to_many :ingridients

  has_many :variants
end
