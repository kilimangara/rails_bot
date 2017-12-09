# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171209154923) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_category_id"
  end

  create_table "categories_products", id: false, force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "product_id", null: false
  end

  create_table "chats", force: :cascade do |t|
    t.integer "chat_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "merchants", force: :cascade do |t|
    t.string "phone"
    t.string "name"
    t.integer "chat_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notification_locations", force: :cascade do |t|
    t.float "longitude"
    t.float "latitude"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_lines", force: :cascade do |t|
    t.string "name"
    t.integer "price"
    t.integer "quantity"
    t.bigint "parent_order_line_id"
    t.bigint "order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_lines_on_order_id"
    t.index ["parent_order_line_id"], name: "index_order_lines_on_parent_order_line_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "shipping_address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.datetime "delivery_date"
    t.integer "total"
    t.boolean "is_stacked"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.integer "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description"
    t.string "image_file_name"
    t.string "image_content_type"
    t.integer "image_file_size"
    t.datetime "image_updated_at"
  end

  create_table "stacked_order_places", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "phone"
    t.string "name"
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "variants", force: :cascade do |t|
    t.string "name"
    t.integer "price"
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  add_foreign_key "order_lines", "order_lines", column: "parent_order_line_id"
  add_foreign_key "orders", "users"
  add_foreign_key "variants", "products"
end
