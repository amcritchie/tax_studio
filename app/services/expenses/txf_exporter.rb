module Expenses
  class TxfExporter
    def initialize(transactions, year:)
      @transactions = transactions
      @year = year
    end

    def to_txf
      lines = []

      # TXF v042 header
      lines << "V042"
      lines << "ATax Studio"
      lines << "D#{Date.current.strftime('%m/%d/%Y')}"
      lines << "^"

      # Group transactions by TXF ref number
      grouped = build_grouped_data

      grouped.each do |txf_ref, group|
        # Summary record (TS)
        lines << "TS"
        lines << "N#{txf_ref}"
        lines << "C1"
        lines << "L1"
        lines << "$#{format_amount(group[:total_cents])}"
        lines << "^"

        # Detail records (TD) per transaction
        group[:transactions].each do |txn|
          amount_cents = adjusted_amount(txn)
          lines << "TD"
          lines << "N#{txf_ref}"
          lines << "C1"
          lines << "L1"
          lines << "D#{txn.transaction_date.strftime('%m/%d/%Y')}"
          lines << "$#{format_amount(amount_cents)}"
          lines << "X#{txn.vendor || txn.raw_description}"
          lines << "^"
        end
      end

      lines.join("\r\n") + "\r\n"
    end

    private

    def build_grouped_data
      grouped = {}

      @transactions.find_each do |txn|
        mapping = ExpenseTransaction::SCHEDULE_C_MAPPING[txn.category]
        next unless mapping

        txf_ref = mapping[:txf_ref]
        grouped[txf_ref] ||= { total_cents: 0, transactions: [] }
        grouped[txf_ref][:transactions] << txn
        grouped[txf_ref][:total_cents] += adjusted_amount(txn)
      end

      grouped
    end

    def adjusted_amount(txn)
      cents = txn.amount_cents
      # Meals are 50% deductible
      cents = (cents * 0.5).round if txn.category == "meals_entertainment"
      cents
    end

    def format_amount(cents)
      # TXF uses negative amounts for expenses
      "%.2f" % -(cents / 100.0)
    end
  end
end
