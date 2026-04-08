module Expenses
  class AiEvaluator
    API_URL = "https://api.anthropic.com/v1/messages"
    MODEL = "claude-haiku-4-5-20251001"
    BATCH_SIZE = 20

    BASE_SYSTEM_PROMPT = <<~PROMPT
      You are a business expense classifier for a solo software developer who runs two web applications:
      1. McRitchie Studio — a task management and AI agent orchestration platform
      2. Turf Monster — a sports pick'em betting app

      The business is a sole proprietorship operating from a home office. The developer uses various SaaS tools, cloud services, AI APIs, and domains for these projects.

      ## Known Business Vendors
      - Heroku, AWS, Google Cloud, DigitalOcean, Cloudflare — hosting/cloud
      - Anthropic, OpenAI, Replicate — AI services
      - GitHub, GitLab, Bitbucket — code hosting
      - Google Domains, Namecheap, GoDaddy — domain registration
      - Figma, Adobe, Canva — design tools
      - Slack, Discord, Notion, Linear — productivity
      - ChatGPT, Claude, Cursor, Copilot — AI dev tools
      - Stripe, Heroku Postgres — infrastructure
      - Udemy, Coursera, O'Reilly — education
      - Apple Developer, Google Play — app store fees
      - Home office: internet, phone, desk equipment, monitors, keyboards

      ## Classification Rules
      - If clearly a business expense, classify as `business_expense`
      - If clearly personal (groceries, restaurants with no business context, entertainment, personal subscriptions like Netflix/Spotify), classify as `not_business_expense`
      - If ambiguous or could be either, classify as `needs_review` and ask a clarifying question
      - Home office expenses (internet, phone) should be classified as business with a note about partial deduction
      - Software subscriptions: business unless clearly personal (gaming, streaming)
      - Meals: only business if clearly a business meeting or travel meal

      ## Account Assignment
      - `mcritchie_studio` — expenses primarily for the Studio platform or general business ops
      - `turf_monster` — expenses primarily for the Turf Monster app
      - `personal` — not a business expense

      ## Response Format
      Respond with a JSON array. Each element must have:
      ```json
      {
        "id": <transaction_id>,
        "classification": "business_expense" | "not_business_expense" | "needs_review",
        "category": "<category_key>",
        "deduction_type": "operating_expense" | "startup_cost",
        "account": "mcritchie_studio" | "turf_monster" | "personal",
        "vendor": "<cleaned vendor name>",
        "business_description": "<what this expense is for>",
        "business_purpose": "<why this is deductible>",
        "ai_question": "<clarifying question if needs_review, null otherwise>"
      }
      ```

      Category keys: software_saas, cloud_hosting, ai_services, home_office, internet_phone,
      professional_services, education_research, marketing_advertising, travel,
      meals_entertainment, office_supplies, hardware_equipment, domain_registration,
      banking_fees, insurance, other_business

      For `not_business_expense`: set category to null, deduction_type to null, account to "personal",
      vendor to cleaned name, business_description to null, business_purpose to null.
    PROMPT

    def initialize(upload)
      @upload = upload
      @api_key = ENV["ANTHROPIC_API_KEY"]
      @system_prompt = build_system_prompt
    end

    def evaluate
      transactions = @upload.expense_transactions.unreviewed.order(:id)
      total = transactions.count
      return if total == 0

      batches = transactions.each_slice(BATCH_SIZE).to_a
      processed = 0

      batches.each_with_index do |batch, idx|
        classify_batch(batch)
        processed += batch.size
        yield({ batch: idx + 1, total_batches: batches.size, processed: processed, total: total }) if block_given?
      end
    end

    def reclassify_with_answer(transaction)
      prompt = build_reclassify_prompt(transaction)
      response = call_api(prompt)
      results = parse_response(response)

      if results&.first
        apply_classification(transaction, results.first)
      end
    end

    private

    def classify_batch(transactions)
      prompt = build_batch_prompt(transactions)
      response = call_api(prompt)
      results = parse_response(response)
      return unless results

      results_by_id = results.index_by { |r| r["id"] }
      transactions.each do |txn|
        result = results_by_id[txn.id]
        apply_classification(txn, result) if result
      end
    end

    def build_batch_prompt(transactions)
      items = transactions.map do |txn|
        {
          id: txn.id,
          date: txn.transaction_date.to_s,
          description: txn.raw_description,
          amount: txn.formatted_amount,
          card: txn.payment_method
        }
      end

      "Classify these #{items.size} transactions:\n\n```json\n#{JSON.pretty_generate(items)}\n```"
    end

    def build_reclassify_prompt(transaction)
      item = {
        id: transaction.id,
        date: transaction.transaction_date.to_s,
        description: transaction.raw_description,
        amount: transaction.formatted_amount,
        card: transaction.payment_method
      }

      <<~PROMPT
        Re-classify this transaction. Previously it was marked as needs_review.

        AI's original question: #{transaction.ai_question}
        User's answer: #{transaction.user_answer}

        Transaction:
        ```json
        #{JSON.pretty_generate([item])}
        ```

        Based on the user's answer, classify this as either business_expense or not_business_expense (not needs_review again).
      PROMPT
    end

    def apply_classification(transaction, result)
      attrs = {
        classification: result["classification"],
        category: result["category"],
        deduction_type: result["deduction_type"],
        account: result["account"],
        vendor: result["vendor"],
        business_description: result["business_description"],
        business_purpose: result["business_purpose"],
        ai_question: result["ai_question"]
      }

      case result["classification"]
      when "business_expense"
        attrs[:status] = "classified"
        attrs[:excluded] = false
        attrs[:excluded_by] = "ai"
      when "not_business_expense"
        attrs[:status] = "classified"
        attrs[:excluded] = true
        attrs[:excluded_by] = "ai"
        attrs[:excluded_at] = Time.current
        attrs[:exclude_reason] = result["business_purpose"].presence || "AI: not a business expense"
      when "needs_review"
        attrs[:status] = "needs_review"
      end

      transaction.update!(attrs)
    end

    def call_api(user_message)
      uri = URI(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = @api_key
      request["anthropic-version"] = "2023-06-01"

      request.body = {
        model: MODEL,
        max_tokens: 4096,
        system: @system_prompt,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Claude API error: #{response.code} — #{response.body}"
      end

      JSON.parse(response.body)
    end

    def build_system_prompt
      guide = ExpenseGuide.current
      if guide.content.present?
        BASE_SYSTEM_PROMPT + "\n\n## Additional Classification Guide\n\n" + guide.content
      else
        BASE_SYSTEM_PROMPT
      end
    end

    def parse_response(response)
      text = response.dig("content", 0, "text")
      return nil unless text

      json_match = text.match(/\[[\s\S]*\]/)
      return nil unless json_match

      JSON.parse(json_match[0])
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse AI response: #{e.message}")
      nil
    end
  end
end
