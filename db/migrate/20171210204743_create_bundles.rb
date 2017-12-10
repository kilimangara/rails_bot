class CreateBundles < ActiveRecord::Migration[5.1]
  def change
    create_table :bundles do |t|
      t.string :name
      t.integer :price
      t.boolean :active, default: true
      t.timestamps
    end

  end
end
