class CreateInsults < ActiveRecord::Migration[6.1]
  def change
    create_table :insults do |t|
      t.text :content

      t.timestamps
    end
  end
end
