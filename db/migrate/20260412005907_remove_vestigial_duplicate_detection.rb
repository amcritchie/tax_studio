class RemoveVestigialDuplicateDetection < ActiveRecord::Migration[7.2]
  def change
    remove_index :expense_transactions, name: :index_expense_transactions_on_duplicate_detection, if_exists: true
    remove_column :expense_uploads, :duplicates_skipped, :integer, default: 0
  end
end
