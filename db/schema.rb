# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_12_223730) do
  create_table "offers", force: :cascade do |t|
    t.string "subcategory_slug", null: false
    t.integer "position", null: false
    t.string "merchant", null: false
    t.string "title", null: false
    t.string "description", null: false
    t.string "discount_text", null: false
    t.integer "hue", default: 210, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subcategory_slug", "position"], name: "index_offers_on_subcategory_slug_and_position", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "public_id", null: false
    t.string "display_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
  end
end
