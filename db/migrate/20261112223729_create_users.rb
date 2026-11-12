class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Stable, opaque application ID. This (and nothing else) is what the app
      # sends to LaunchDarkly as the signed-in context key.
      t.string :public_id, null: false
      t.string :display_name, null: false

      t.timestamps
    end
    add_index :users, :public_id, unique: true
  end
end
