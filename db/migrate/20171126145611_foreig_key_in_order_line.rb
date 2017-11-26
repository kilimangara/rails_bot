class ForeigKeyInOrderLine < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :order_lines, :order_lines, column: 'parent_order_line_id', null: true
  end
end
