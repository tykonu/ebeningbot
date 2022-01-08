class ChangeUserPreferenceUserIdToString < ActiveRecord::Migration[6.1]
  def change
    change_column :user_preferences, :user_id, :string
  end
end
