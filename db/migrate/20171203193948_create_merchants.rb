class CreateMerchants < ActiveRecord::Migration[5.1]
  def change
    create_table :merchants do |t|
      t.string :phone, unique: true
      t.string :name
      t.integer :chat_id, null: true

      t.timestamps
    end
  end
end
