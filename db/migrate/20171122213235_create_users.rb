class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :phone, unique: true
      t.string :name, null: true
      t.string :address

      t.timestamps
    end
  end
end
