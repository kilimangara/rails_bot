class AddReferences < ActiveRecord::Migration[5.1]
  def change
    create_join_table :categories, :products
    add_reference :orders, :user, index: true, foreign_key: true
  end
end
