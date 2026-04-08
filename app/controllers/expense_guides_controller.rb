class ExpenseGuidesController < ApplicationController
  before_action :require_admin
  before_action :set_guide

  def show
    renderer = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank" }),
      fenced_code_blocks: true, tables: true, autolink: true
    )
    @rendered_content = renderer.render(@guide.content).html_safe
    @feedback_count = ExpenseTransaction.user_overridden.count
  end

  def update
    rescue_and_log(target: @guide) do
      @guide.update!(content: params[:content])
      redirect_to expense_guide_path, notice: "Guide saved."
    end
  rescue StandardError => e
    redirect_to expense_guide_path, alert: "Save failed: #{e.message}"
  end

  def generate_from_feedback
    rescue_and_log(target: @guide) do
      feedback = build_feedback_summary
      raise "No user feedback found. Override some transactions first." if feedback.blank?

      new_content = call_guide_generator(feedback)
      @guide.update!(content: new_content)
      redirect_to expense_guide_path, notice: "Guide regenerated from #{feedback[:count]} user overrides."
    end
  rescue StandardError => e
    redirect_to expense_guide_path, alert: "Generation failed: #{e.message}"
  end

  private

  def set_guide
    @guide = ExpenseGuide.current
  end

  def build_feedback_summary
    overrides = ExpenseTransaction.user_overridden.order(:updated_at).limit(200)
    return nil if overrides.empty?

    items = overrides.map do |txn|
      {
        vendor: txn.vendor || txn.raw_description,
        amount: txn.formatted_amount,
        excluded: txn.excluded,
        reason: txn.exclude_reason,
        category: txn.category,
        account: txn.account
      }
    end

    { count: overrides.size, items: items }
  end

  def call_guide_generator(feedback)
    uri = URI("https://api.anthropic.com/v1/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"

    system = <<~PROMPT
      You are an expense classification guide generator. Given user feedback on expense transactions
      (which ones they included/excluded and why), generate a comprehensive markdown guide for an AI
      expense classifier. The guide should include rules, vendor patterns, and category assignments
      based on the user's decisions. Keep the format clean and organized with markdown headers.
    PROMPT

    user_msg = <<~MSG
      Here is the current guide:
      ```
      #{@guide.content}
      ```

      Here are #{feedback[:count]} user overrides (their include/exclude decisions with reasons):
      ```json
      #{JSON.pretty_generate(feedback[:items])}
      ```

      Generate an updated expense classification guide that incorporates these user decisions as rules.
      Keep the existing structure but add/modify rules based on the feedback patterns.
      Output only the markdown content, no code fences around the entire output.
    MSG

    request.body = {
      model: "claude-haiku-4-5-20251001",
      max_tokens: 4096,
      system: system,
      messages: [{ role: "user", content: user_msg }]
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "Claude API error: #{response.code} — #{response.body}"
    end

    parsed = JSON.parse(response.body)
    parsed.dig("content", 0, "text") || raise("Empty response from Claude API")
  end
end
