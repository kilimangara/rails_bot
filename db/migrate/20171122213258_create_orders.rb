class CreateOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :orders do |t|
      t.string :shipping_address, null:false

      t.timestamps
    end
  end
end
