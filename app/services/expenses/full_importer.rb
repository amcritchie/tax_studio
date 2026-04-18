require "csv"

module Expenses
  class FullImporter
    Result = Struct.new(:upload, :imported, :errors, keyword_init: true)

    def initialize(file, original_filename, user)
      @file = file
      @original_filename = original_filename
      @user = user
    end

    def import
      errors = []

      # Upload dedup — reject if filename already exists
      if ExpenseUpload.exists?(filename: @original_filename)
        return Result.new(upload: nil, imported: 0,
                          errors: ["A file named '#{@original_filename}' has already been imported."])
      end

      upload = ExpenseUpload.create!(
        user: @user,
        filename: @original_filename,
        card_type: "import",
        status: "evaluated"
      )

      imported = 0

      CSV.foreach(@file.path, headers: true) do |row|
        begin
          date = Date.parse(row["transaction_date"]) rescue nil
          next unless date

          amount_cents = row["amount_cents"].to_i
          next if amount_cents == 0

          normalized = row["normalized_description"].to_s.strip
          next if normalized.blank?

          upload.expense_transactions.create!(
            transaction_date: date,
            raw_description: row["raw_description"],
            normalized_description: normalized,
            amount_cents: amount_cents,
            payment_method_id: PaymentMethod.find_by(parser_key: row["payment_method"])&.id,
            status: row["status"].presence || "classified",
            classification: row["classification"],
            category: row["category"],
            deduction_type: row["deduction_type"],
            account: row["account"],
            vendor: row["vendor"],
            business_description: row["business_description"],
            business_purpose: row["business_purpose"],
            ai_question: row["ai_question"],
            user_answer: row["user_answer"],
            manually_overridden: row["manually_overridden"] == "true",
            excluded: row["excluded"] == "true",
            exclude_reason: row["exclude_reason"],
            excluded_by: row["excluded_by"],
            excluded_at: row["excluded_at"].present? ? Time.parse(row["excluded_at"]) : nil,
          )
          imported += 1
        rescue StandardError => e
          errors << "Row: #{e.message}"
        end
      end

      upload.update!(
        transaction_count: imported
      )

      Result.new(upload: upload, imported: imported, errors: errors)
    end
  end
end
