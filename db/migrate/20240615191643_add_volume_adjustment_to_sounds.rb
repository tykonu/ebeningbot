class AddVolumeAdjustmentToSounds < ActiveRecord::Migration[7.1]
  def change
    add_column :sounds, :volume_adjustment, :decimal, precision: 5, scale: 2
  end
end
