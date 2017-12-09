class CreateStackedOrderPlaces < ActiveRecord::Migration[5.1]
  def change
    create_table :stacked_order_places do |t|
      t.string :address, null: false, unique:true
      t.timestamps
    end

    add_column :orders, :is_stacked, :boolean
  end
end
