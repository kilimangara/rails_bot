class CreateOrderLines < ActiveRecord::Migration[5.1]
  def change
    create_table :order_lines do |t|

      t.string :name
      t.integer :price
      t.integer :quantity

      t.references :parent_order_line, index: true, null: true
      t.references :order, index:true

      t.timestamps
    end

  end
end
