class AddProductUrl < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :url, :string
  end
end
