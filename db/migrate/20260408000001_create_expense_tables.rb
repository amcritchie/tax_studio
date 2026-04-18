class CreateExpenseTables < ActiveRecord::Migration[7.2]
  def change
    # Users (required by Studio engine)
    create_table :users do |t|
      t.string :name
      t.string :first_name
      t.string :last_name
      t.string :email, null: false
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :role, default: "viewer"
      t.string :slug

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :slug, unique: true

    # Error Logs (required by Studio engine)
    create_table :error_logs do |t|
      t.text :message
      t.text :inspect
      t.text :backtrace
      t.string :target_type
      t.bigint :target_id
      t.string :parent_type
      t.bigint :parent_id
      t.string :target_name
      t.string :parent_name
      t.string :slug

      t.timestamps
    end
    add_index :error_logs, [:target_type, :target_id]
    add_index :error_logs, [:parent_type, :parent_id]
    add_index :error_logs, :slug, unique: true

    # Theme Settings (required by Studio engine)
    create_table :theme_settings do |t|
      t.string :app_name, null: false
      t.string :primary
      t.string :accent1
      t.string :accent2
      t.string :warning
      t.string :danger
      t.string :dark
      t.string :light
      t.string :slug

      t.timestamps
    end
    add_index :theme_settings, :app_name, unique: true

    # Payment Methods
    create_table :payment_methods do |t|
      t.string :name, null: false
      t.string :slug
      t.string :last_four
      t.string :parser_key
      t.string :color
      t.string :color_secondary
      t.string :logo
      t.integer :position, default: 0
      t.string :status, default: "active"
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :payment_methods, :slug, unique: true

    # Expense Uploads
    create_table :expense_uploads do |t|
      t.string :filename, null: false
      t.string :slug
      t.string :card_type
      t.string :status, default: "pending"
      t.integer :transaction_count, default: 0
      t.integer :credits_skipped, default: 0
      t.jsonb :processing_summary
      t.datetime :first_transaction_at
      t.datetime :last_transaction_at
      t.datetime :processed_at
      t.datetime :evaluated_at
      t.references :user, null: false, foreign_key: true
      t.references :payment_method, foreign_key: true

      t.timestamps
    end
    add_index :expense_uploads, :slug, unique: true
    add_index :expense_uploads, :status

    # Expense Transactions
    create_table :expense_transactions do |t|
      t.string :slug
      t.references :expense_upload, null: false, foreign_key: true
      t.date :transaction_date, null: false
      t.text :raw_description, null: false
      t.text :normalized_description
      t.integer :amount_cents, null: false
      t.references :payment_method, foreign_key: true
      t.string :status, default: "unreviewed"

      # AI classification fields
      t.string :classification
      t.string :category
      t.string :deduction_type
      t.string :account
      t.string :vendor
      t.text :business_description
      t.text :business_purpose
      t.text :ai_question
      t.text :user_answer
      t.boolean :manually_overridden, default: false

      # Exclude/feedback fields
      t.boolean :excluded, default: false
      t.string :exclude_reason
      t.string :excluded_by
      t.datetime :excluded_at

      t.timestamps
    end
    add_index :expense_transactions, :slug, unique: true
    add_index :expense_transactions, :status
    add_index :expense_transactions, :classification
    add_index :expense_transactions, :excluded
    add_index :expense_transactions, :transaction_date
    add_index :expense_transactions, [:status, :classification, :excluded], name: "index_expense_txns_on_status_class_excluded"

    # Expense Guides
    create_table :expense_guides do |t|
      t.text :content
      t.string :slug

      t.timestamps
    end
    add_index :expense_guides, :slug, unique: true
  end
end
