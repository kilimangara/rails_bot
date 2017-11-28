class CreateVariants < ActiveRecord::Migration[5.1]
  def change
    create_table :variants do |t|

      t.string :name
      t.belongs_to :products, foreign_key: true

      t.timestamps
    end

    add_column :products, :description, :string
  end
end
