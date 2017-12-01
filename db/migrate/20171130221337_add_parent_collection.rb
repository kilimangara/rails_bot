class AddParentCollection < ActiveRecord::Migration[5.1]
  def change
    add_column :categories, :parent_category_id, :integer
  end
end
