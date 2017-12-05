class CreateNotificationLocations < ActiveRecord::Migration[5.1]
  def change
    create_table :notification_locations do |t|
      t.float :longitude
      t.float :latitude
      t.string :description

      t.timestamps
    end
  end
end
