class AddAttachmentToProduct < ActiveRecord::Migration[5.1]
  def change
    add_attachment :products, :image
    remove_column :products, :url
  end
end
