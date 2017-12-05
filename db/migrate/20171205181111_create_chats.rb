class CreateChats < ActiveRecord::Migration[5.1]
  def change
    create_table :chats do |t|
      t.integer :chat_id, unique: true
      t.string :name

      t.timestamps
    end
  end
end
