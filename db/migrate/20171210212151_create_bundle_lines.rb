class CreateBundleLines < ActiveRecord::Migration[5.1]
  def change
    create_table :bundle_lines do |t|
      t.belongs_to :bundle, index: true
      t.belongs_to :variant, index: true
      t.integer :quantity

      t.timestamps
    end
  end
end
