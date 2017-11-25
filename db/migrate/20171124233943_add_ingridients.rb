class AddIngridients < ActiveRecord::Migration[5.1]
  def change
    create_table :ingridient do |t|
      t.string :name
      t.integer :price

      t.timestamps
    end

    create_join_table :ingridients, :products
  end
end
