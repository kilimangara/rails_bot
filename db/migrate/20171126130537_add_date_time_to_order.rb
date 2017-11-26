class AddDateTimeToOrder < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :delivery_date, :datetime
  end
end
