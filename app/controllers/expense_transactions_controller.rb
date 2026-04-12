class ExpenseTransactionsController < ApplicationController
  before_action :require_admin
  before_action :set_transaction, only: [:show, :update, :answer_review, :toggle_exclude, :re_evaluate]

  def index
    @transactions = ExpenseTransaction.includes(:expense_upload).recent

    # Filters
    @transactions = @transactions.where(status: params[:status]) if params[:status].present?
    @transactions = @transactions.by_category(params[:category]) if params[:category].present?
    @transactions = @transactions.by_account(params[:account]) if params[:account].present?
    @transactions = @transactions.by_card(params[:payment_method]) if params[:payment_method].present?
    @transactions = @transactions.by_month(params[:month]) if params[:month].present?
    if params[:q].present?
      @transactions = @transactions.where("raw_description ILIKE ? OR vendor ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end

    @per_page = 50
    @page = (params[:page] || 1).to_i
    @total_count = @transactions.count
    @transactions = @transactions.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
  end

  def update
    rescue_and_log(target: @transaction) do
      @transaction.update!(transaction_params.merge(manually_overridden: true, status: "reviewed"))
      respond_to do |format|
        format.html { redirect_to expense_transaction_path(@transaction.slug), notice: "Transaction updated." }
        format.json { render json: transaction_json }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { render :show, status: :unprocessable_entity }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def answer_review
    rescue_and_log(target: @transaction) do
      @transaction.update!(user_answer: params[:user_answer])
      evaluator = Expenses::AiEvaluator.new(@transaction.expense_upload)
      evaluator.reclassify_with_answer(@transaction)
      @transaction.reload
      respond_to do |format|
        format.html { redirect_to expense_transaction_path(@transaction.slug), notice: "Re-classified based on your answer." }
        format.json { render json: transaction_json }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to expense_transaction_path(@transaction.slug), alert: "Review failed: #{e.message}" }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def toggle_exclude
    rescue_and_log(target: @transaction) do
      new_excluded = !@transaction.excluded
      if new_excluded && params[:exclude_reason].blank?
        raise "Exclude reason is required"
      end
      attrs = {
        excluded: new_excluded,
        exclude_reason: params[:exclude_reason].presence,
        excluded_by: "user",
        excluded_at: new_excluded ? Time.current : nil,
        status: "reviewed"
      }
      if new_excluded
        attrs[:account] = "personal"
      else
        attrs[:account] = nil
        attrs[:exclude_reason] = nil
        attrs[:excluded_by] = nil
      end
      @transaction.update!(attrs)
      respond_to do |format|
        format.html { redirect_back fallback_location: expense_transactions_path, notice: @transaction.excluded ? "Excluded." : "Included." }
        format.json { render json: transaction_json }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_back fallback_location: expense_transactions_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def re_evaluate
    rescue_and_log(target: @transaction) do
      @transaction.update!(
        status: "unreviewed",
        classification: nil,
        category: nil,
        deduction_type: nil,
        account: nil,
        vendor: nil,
        business_description: nil,
        business_purpose: nil,
        ai_question: nil,
        user_answer: nil,
        manually_overridden: false
      )
      evaluator = Expenses::AiEvaluator.new(@transaction.expense_upload)
      evaluator.evaluate_single(@transaction)
      @transaction.reload
      respond_to do |format|
        format.html { redirect_to expense_transaction_path(@transaction.slug), notice: "Transaction re-evaluated by AI." }
        format.json { render json: transaction_json }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to expense_transaction_path(@transaction.slug), alert: "Re-evaluation failed: #{e.message}" }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def export
    transactions = ExpenseTransaction.business_expenses.recent
    csv = Expenses::Exporter.new(transactions).to_csv
    send_data csv, filename: "business_expenses_#{Date.current}.csv", type: "text/csv"
  end

  def export_full
    year = (params[:year] || 2025).to_i
    date_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
    transactions = ExpenseTransaction.where(transaction_date: date_range).recent
    csv = Expenses::FullExporter.new(transactions).to_csv
    send_data csv, filename: "tax_studio_full_export_#{year}.csv", type: "text/csv"
  end

  def import_data
    unless params[:file].present?
      return redirect_to expense_uploads_path, alert: "Please select a CSV file to import."
    end

    rescue_and_log(target: nil) do
      result = Expenses::FullImporter.new(params[:file], params[:file].original_filename, current_user).import

      if result.errors.any? && result.imported == 0
        redirect_to expense_uploads_path, alert: result.errors.first
      else
        msg = "Imported #{result.imported} transactions."
        msg += " Errors: #{result.errors.size}" if result.errors.any?
        redirect_to expense_uploads_path, notice: msg
      end
    end
  rescue StandardError => e
    redirect_to expense_uploads_path, alert: "Import failed: #{e.message}"
  end

  def turbotax
    @year = (params[:year] || 2025).to_i
    date_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @business = ExpenseTransaction.business_expenses.where(transaction_date: date_range)
    @all_transactions = ExpenseTransaction.where(transaction_date: date_range)
    @needs_review = @all_transactions.where(status: "needs_review")
    @unreviewed = @all_transactions.where(status: "unreviewed")

    @schedule_c = Expenses::ScheduleCExporter.new(@business)
  end

  def turbotax_txf
    year = (params[:year] || 2025).to_i
    date_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
    transactions = ExpenseTransaction.business_expenses.where(transaction_date: date_range)
    txf = Expenses::TxfExporter.new(transactions, year: year).to_txf
    send_data txf, filename: "schedule_c_#{year}.txf", type: "application/octet-stream"
  end

  def turbotax_csv
    year = (params[:year] || 2025).to_i
    date_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
    transactions = ExpenseTransaction.business_expenses.where(transaction_date: date_range)
    csv = Expenses::ScheduleCExporter.new(transactions).to_csv
    send_data csv, filename: "schedule_c_summary_#{year}.csv", type: "text/csv"
  end

  def summary
    @business = ExpenseTransaction.business_expenses
    @needs_review = ExpenseTransaction.needs_review
    @total_business_cents = @business.sum(:amount_cents)

    @by_category = @business.group(:category).sum(:amount_cents).sort_by { |_, v| -v }
    @by_card = @business.group(:payment_method).sum(:amount_cents).sort_by { |_, v| -v }
    @by_account = @business.group(:account).sum(:amount_cents).sort_by { |_, v| -v }
    @by_month = @business.group("to_char(transaction_date, 'YYYY-MM')").sum(:amount_cents).sort_by { |k, _| k }
  end

  def tax_report
    @year = (params[:year] || 2025).to_i
    date_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @business = ExpenseTransaction.business_expenses.where(transaction_date: date_range)
    @all_transactions = ExpenseTransaction.where(transaction_date: date_range)
    @needs_review = @all_transactions.where(status: "needs_review")
    @unreviewed = @all_transactions.where(status: "unreviewed")

    @total_business_cents = @business.sum(:amount_cents)
    @total_all_cents = @all_transactions.not_excluded.sum(:amount_cents)

    @by_category = @business.group(:category).sum(:amount_cents).sort_by { |_, v| -v }
    @by_deduction_type = @business.group(:deduction_type).sum(:amount_cents).sort_by { |_, v| -v }
    @by_account = @business.group(:account).sum(:amount_cents).sort_by { |_, v| -v }
    @by_month = @business.group("to_char(transaction_date, 'YYYY-MM')").sum(:amount_cents).sort_by { |k, _| k }
    @by_card = @business.group(:payment_method).sum(:amount_cents).sort_by { |_, v| -v }
  end

  private

  def set_transaction
    @transaction = ExpenseTransaction.find_by(slug: params[:slug])
    return redirect_to expense_transactions_path, alert: "Transaction not found" unless @transaction
  end

  def transaction_params
    params.require(:expense_transaction).permit(:classification, :category, :deduction_type, :account, :vendor, :business_purpose)
  end

  def transaction_json
    {
      slug: @transaction.slug,
      status: @transaction.status,
      excluded: @transaction.excluded,
      exclude_reason: @transaction.exclude_reason,
      excluded_by: @transaction.excluded_by,
      classification: @transaction.classification,
      category: @transaction.category,
      category_display: @transaction.category_display,
      account: @transaction.account,
      account_display: @transaction.account_display,
      deduction_type: @transaction.deduction_type,
      business_expense: @transaction.business_expense?,
      needs_review: @transaction.needs_review?,
      reviewed: @transaction.reviewed?
    }
  end
end
