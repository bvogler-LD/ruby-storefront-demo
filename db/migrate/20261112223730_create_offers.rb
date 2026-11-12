class CreateOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :offers do |t|
      t.string :subcategory_slug, null: false
      # 1-based ordinal within the subcategory. Defines the single deterministic
      # ordering shared by pagination and infinite scroll.
      t.integer :position, null: false
      t.string :merchant, null: false
      t.string :title, null: false
      t.string :description, null: false
      t.string :discount_text, null: false
      t.integer :hue, null: false, default: 210

      t.timestamps
    end
    add_index :offers, [ :subcategory_slug, :position ], unique: true
  end
end
