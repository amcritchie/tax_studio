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

ActiveRecord::Schema[7.2].define(version: 2026_04_12_005907) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "error_logs", force: :cascade do |t|
    t.text "message"
    t.text "inspect"
    t.text "backtrace"
    t.string "target_type"
    t.bigint "target_id"
    t.string "parent_type"
    t.bigint "parent_id"
    t.string "target_name"
    t.string "parent_name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_type", "parent_id"], name: "index_error_logs_on_parent_type_and_parent_id"
    t.index ["slug"], name: "index_error_logs_on_slug", unique: true
    t.index ["target_type", "target_id"], name: "index_error_logs_on_target_type_and_target_id"
  end

  create_table "expense_guides", force: :cascade do |t|
    t.text "content"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_expense_guides_on_slug", unique: true
  end

  create_table "expense_transactions", force: :cascade do |t|
    t.string "slug"
    t.bigint "expense_upload_id", null: false
    t.date "transaction_date", null: false
    t.text "raw_description", null: false
    t.text "normalized_description"
    t.integer "amount_cents", null: false
    t.string "payment_method"
    t.string "status", default: "unreviewed"
    t.string "classification"
    t.string "category"
    t.string "deduction_type"
    t.string "account"
    t.string "vendor"
    t.text "business_description"
    t.text "business_purpose"
    t.text "ai_question"
    t.text "user_answer"
    t.boolean "manually_overridden", default: false
    t.boolean "excluded", default: false
    t.string "exclude_reason"
    t.string "excluded_by"
    t.datetime "excluded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_upload_id"], name: "index_expense_transactions_on_expense_upload_id"
    t.index ["slug"], name: "index_expense_transactions_on_slug", unique: true
  end

  create_table "expense_uploads", force: :cascade do |t|
    t.string "filename", null: false
    t.string "slug"
    t.string "card_type"
    t.string "status", default: "pending"
    t.integer "transaction_count", default: 0
    t.integer "unique_transactions", default: 0
    t.integer "credits_skipped", default: 0
    t.jsonb "processing_summary"
    t.datetime "first_transaction_at"
    t.datetime "last_transaction_at"
    t.datetime "processed_at"
    t.datetime "evaluated_at"
    t.bigint "user_id", null: false
    t.bigint "payment_method_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_expense_uploads_on_payment_method_id"
    t.index ["slug"], name: "index_expense_uploads_on_slug", unique: true
    t.index ["user_id"], name: "index_expense_uploads_on_user_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.string "last_four"
    t.string "parser_key"
    t.string "color"
    t.string "color_secondary"
    t.string "logo"
    t.integer "position", default: 0
    t.string "status", default: "active"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_payment_methods_on_slug", unique: true
    t.index ["user_id"], name: "index_payment_methods_on_user_id"
  end

  create_table "theme_settings", force: :cascade do |t|
    t.string "app_name", null: false
    t.string "primary"
    t.string "accent1"
    t.string "accent2"
    t.string "warning"
    t.string "danger"
    t.string "dark"
    t.string "light"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_name"], name: "index_theme_settings_on_app_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "first_name"
    t.string "last_name"
    t.string "email", null: false
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.string "role", default: "viewer"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "expense_transactions", "expense_uploads"
  add_foreign_key "expense_uploads", "payment_methods"
  add_foreign_key "expense_uploads", "users"
  add_foreign_key "payment_methods", "users"
end
