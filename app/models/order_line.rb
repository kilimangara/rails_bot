class OrderLine < ApplicationRecord

  belongs_to :order

  belongs_to :parent_order_line, class_name: 'OrderLine', required: false

  has_many :additional_lines, class_name: 'OrderLine', foreign_key: 'parent_order_line_id'
end
