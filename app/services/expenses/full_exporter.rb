require "csv"

module Expenses
  class FullExporter
    HEADERS = %w[
      transaction_date raw_description normalized_description amount_cents
      payment_method status classification category deduction_type account
      vendor business_description business_purpose ai_question user_answer
      manually_overridden excluded exclude_reason excluded_by excluded_at
    ].freeze

    def initialize(transactions)
      @transactions = transactions
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << HEADERS
        @transactions.find_each do |txn|
          csv << [
            txn.transaction_date&.iso8601,
            txn.raw_description,
            txn.normalized_description,
            txn.amount_cents,
            txn.payment_method&.parser_key,
            txn.status,
            txn.classification,
            txn.category,
            txn.deduction_type,
            txn.account,
            txn.vendor,
            txn.business_description,
            txn.business_purpose,
            txn.ai_question,
            txn.user_answer,
            txn.manually_overridden,
            txn.excluded,
            txn.exclude_reason,
            txn.excluded_by,
            txn.excluded_at&.iso8601,
          ]
        end
      end
    end
  end
end
