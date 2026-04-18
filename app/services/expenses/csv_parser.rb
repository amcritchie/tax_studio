module Expenses
  class CsvParser
    Result = Struct.new(:transactions, :card_type, :credits_skipped, :skipped_details, :errors, keyword_init: true)

    CARD_PATTERNS = {
      "citi" => {
        headers: /status.*date.*description.*debit.*credit/i,
        date_col: "Date",
        description_col: "Description",
        debit_col: "Debit",
        credit_col: "Credit",
        date_format: "%m/%d/%Y"
      },
      "capital_one_spark" => {
        headers: /transaction date.*posted date.*card no.*description.*category.*debit.*credit/i,
        date_col: "Transaction Date",
        description_col: "Description",
        debit_col: "Debit",
        credit_col: "Credit"
      },
      "chase" => {
        headers: /card.*transaction date.*post date.*description.*category.*type.*amount/i,
        date_col: "Transaction Date",
        description_col: "Description",
        amount_col: "Amount",
        negate_amount: true,
        date_format: "%m/%d/%Y"
      },
      "amex_platinum" => {
        headers: /date.*description.*amount/i,
        date_col: "Date",
        description_col: "Description",
        amount_col: "Amount"
      },
      "robinhood" => {
        headers: /transaction.*date.*description.*amount.*type/i,
        date_col: "Date",
        description_col: "Description",
        amount_col: "Amount"
      }
    }.freeze

    def initialize(upload)
      @upload = upload
    end

    def parse
      file = download_file
      spreadsheet = open_spreadsheet(file)

      # Scan for header row — may not be row 1 (e.g. Amex xlsx has metadata rows)
      header_row_num, headers, card_type = find_header_row(spreadsheet)

      card_type = @upload.card_type.presence || card_type
      config = CARD_PATTERNS[card_type]

      # Auto-link payment method if not already set
      if card_type.present? && @upload.payment_method_id.nil?
        pm = PaymentMethod.find_by(parser_key: card_type)
        @upload.update_column(:payment_method_id, pm.id) if pm
      end

      transactions = []
      credits_skipped = 0
      skipped_details = []
      errors = []

      ((header_row_num + 1)..spreadsheet.last_row).each do |row_num|
        row = spreadsheet.row(row_num)
        next if row.all?(&:blank?)

        begin
          parsed = parse_row(row, headers, config, card_type)
          next unless parsed

          if parsed[:amount_cents] <= 0
            credits_skipped += 1
            skipped_details << { reason: "credit", date: parsed[:date]&.iso8601, description: parsed[:raw_description], amount_cents: parsed[:amount_cents] }
            next
          end


          txn = @upload.expense_transactions.create!(
            transaction_date: parsed[:date],
            raw_description: parsed[:raw_description],
            normalized_description: parsed[:normalized_description],
            amount_cents: parsed[:amount_cents],
            payment_method_id: PaymentMethod.find_by(parser_key: card_type)&.id
          )
          transactions << txn
        rescue StandardError => e
          errors << "Row #{row_num}: #{e.message}"
        end
      end

      Result.new(
        transactions: transactions,
        card_type: card_type,
        credits_skipped: credits_skipped,
        skipped_details: skipped_details,
        errors: errors
      )
    ensure
      file&.close
      file&.unlink if file.respond_to?(:unlink)
    end

    private

    def download_file
      tempfile = Tempfile.new(["expense", File.extname(@upload.filename)])
      tempfile.binmode
      tempfile.write(@upload.file.download)
      tempfile.rewind
      tempfile
    end

    def open_spreadsheet(file)
      ext = File.extname(@upload.filename).downcase
      case ext
      when ".csv"
        Roo::CSV.new(file.path)
      when ".xlsx"
        Roo::Excelx.new(file.path)
      when ".xls"
        Roo::Excel.new(file.path)
      else
        Roo::Spreadsheet.open(file.path)
      end
    end

    def find_header_row(spreadsheet)
      max_scan = [spreadsheet.last_row, 20].min
      (1..max_scan).each do |row_num|
        row = spreadsheet.row(row_num)
        next if row.all?(&:blank?)
        headers = row.map(&:to_s).map(&:strip)
        card_type = detect_card_type(headers)
        return [row_num, headers, card_type] if card_type
      end
      # Fallback to row 1 if no pattern matched
      headers = spreadsheet.row(1).map(&:to_s).map(&:strip)
      [1, headers, nil]
    end

    def detect_card_type(headers)
      header_line = headers.join(",")
      CARD_PATTERNS.each do |type, config|
        return type if header_line.match?(config[:headers])
      end
      nil
    end

    def parse_row(row, headers, config, card_type)
      row_hash = headers.zip(row).to_h

      date = parse_date(find_value(row_hash, config&.dig(:date_col) || "Date"), config&.dig(:date_format))
      return nil unless date

      description = find_value(row_hash, config&.dig(:description_col) || "Description").to_s.strip
      return nil if description.blank?

      amount_cents = parse_amount(row_hash, config, card_type)
      return nil unless amount_cents

      {
        date: date,
        raw_description: description,
        normalized_description: normalize_description(description),
        amount_cents: amount_cents
      }
    end

    def find_value(row_hash, key)
      return row_hash[key] if row_hash.key?(key)
      # Case-insensitive fuzzy match
      row_hash.find { |k, _| k.to_s.strip.downcase == key.to_s.strip.downcase }&.last
    end

    def parse_date(value, format = nil)
      return nil if value.blank?
      case value
      when Date, DateTime, Time
        value.to_date
      when String
        format ? Date.strptime(value, format) : Date.parse(value)
      else
        format ? Date.strptime(value.to_s, format) : Date.parse(value.to_s)
      end
    rescue Date::Error, ArgumentError
      nil
    end

    def parse_amount(row_hash, config, card_type)
      if config && config[:amount_col]
        raw = find_value(row_hash, config[:amount_col])
        cents = to_cents(raw)
        cents = -cents if cents && config[:negate_amount]
        return cents
      end

      # Debit/Credit columns
      debit = to_cents(find_value(row_hash, config&.dig(:debit_col) || "Debit"))
      credit = to_cents(find_value(row_hash, config&.dig(:credit_col) || "Credit"))

      return debit if debit && debit > 0
      return -credit if credit && credit > 0
      debit || 0
    end

    def to_cents(value)
      return nil if value.blank?
      cleaned = value.to_s.gsub(/[$,\s]/, "")
      return nil if cleaned.blank? || cleaned == "-"
      (cleaned.to_f * 100).round
    end

    def normalize_description(desc)
      desc.to_s.strip.gsub(/\s+/, " ").downcase.gsub(/[^a-z0-9\s]/, "").strip
    end

  end
end
