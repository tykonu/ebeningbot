class CreateSounds < ActiveRecord::Migration[6.1]
  def change
    create_table :sounds do |t|
      t.string :name

      t.timestamps
    end
    add_index :sounds, :name, unique: true
  end
end
