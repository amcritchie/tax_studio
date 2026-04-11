require "csv"

module Expenses
  class ScheduleCExporter
    HEADERS = ["Schedule C Line", "Line Name", "App Categories", "Amount", "Transaction Count", "Notes"].freeze

    def initialize(transactions)
      @transactions = transactions
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << HEADERS

        summary_rows.each do |row|
          csv << [
            "Line #{row[:line]}",
            row[:name],
            row[:categories].join(", "),
            "$#{'%.2f' % (row[:amount_cents] / 100.0)}",
            row[:count],
            row[:notes],
          ]
        end

        csv << []
        csv << ["", "TOTAL", "", "$#{'%.2f' % (total_cents / 100.0)}", total_count, ""]
      end
    end

    def summary_rows
      @summary_rows ||= build_summary
    end

    def total_cents
      summary_rows.sum { |r| r[:amount_cents] }
    end

    def total_count
      summary_rows.sum { |r| r[:count] }
    end

    private

    def build_summary
      # Group by Schedule C line
      by_line = {}

      ExpenseTransaction::SCHEDULE_C_MAPPING.each do |category, mapping|
        line = mapping[:line]
        by_line[line] ||= { line: line, name: mapping[:name], categories: [], amount_cents: 0, count: 0, notes: nil }

        cat_txns = @transactions.where(category: category)
        cat_count = cat_txns.count
        next if cat_count == 0

        cat_cents = cat_txns.sum(:amount_cents)

        # Meals are 50% deductible
        if category == "meals_entertainment"
          cat_cents = (cat_cents * 0.5).round
          by_line[line][:notes] = "50% deductible"
        end

        display = ExpenseTransaction::CATEGORIES[category] || category.titleize
        display = "#{display} (#{mapping[:sub]})" if mapping[:sub] && by_line[line][:categories].any?
        by_line[line][:categories] << display
        by_line[line][:amount_cents] += cat_cents
        by_line[line][:count] += cat_count
      end

      by_line.values
             .select { |r| r[:count] > 0 }
             .sort_by { |r| r[:line] }
    end
  end
end
