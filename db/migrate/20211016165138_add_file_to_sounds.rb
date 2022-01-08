class AddFileToSounds < ActiveRecord::Migration[6.1]
  def change
    add_column :sounds, :file, :binary
  end
end
