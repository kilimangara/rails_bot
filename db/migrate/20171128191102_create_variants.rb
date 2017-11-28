class CreateVariants < ActiveRecord::Migration[5.1]
  def change
    create_table :variants do |t|

      t.string :name
      t.integer :price
      t.belongs_to :product, foreign_key: true, null: true

      t.timestamps
    end

    add_column :products, :description, :string
  end
end
