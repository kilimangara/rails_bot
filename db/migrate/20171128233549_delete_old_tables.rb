class DeleteOldTables < ActiveRecord::Migration[5.1]
  def change
    drop_table :ingridients
    drop_join_table :ingridients, :products
  end
end
