class RenameTableIngridient < ActiveRecord::Migration[5.1]
  def change
    rename_table :ingridient, :ingridients
  end
end
