require "csv"

module Expenses
  class Exporter
    HEADERS = ["Date", "Vendor", "Description", "Amount", "Category", "Deduction Type", "Account", "Card", "Business Purpose"].freeze

    def initialize(transactions)
      @transactions = transactions
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << HEADERS
        @transactions.find_each do |txn|
          csv << [
            txn.transaction_date.strftime("%Y-%m-%d"),
            txn.vendor,
            txn.raw_description,
            txn.formatted_amount,
            txn.category_display,
            txn.deduction_type_display,
            txn.account_display,
            txn.payment_method&.titleize,
            txn.business_purpose
          ]
        end
      end
    end
  end
end
