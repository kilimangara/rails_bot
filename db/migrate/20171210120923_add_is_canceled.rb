class AddIsCanceled < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :canceled, :boolean, default: false
  end
end
