class ExpenseUploadsController < ApplicationController
  before_action :require_admin
  before_action :set_upload, only: [:show, :destroy, :process_file, :evaluate]

  def index
    @uploads = ExpenseUpload.recent.includes(:user, :payment_method)
  end

  def new
    @upload = ExpenseUpload.new
  end

  def create
    payment_method = PaymentMethod.find_by(id: params[:payment_method_id]) if params[:payment_method_id].present?
    @upload = ExpenseUpload.new(
      filename: params[:file]&.original_filename || "unknown",
      user: current_user,
      payment_method: payment_method,
      card_type: payment_method&.parser_key || params[:card_type].presence
    )
    rescue_and_log(target: @upload) do
      @upload.save!
      @upload.file.attach(params[:file])
      redirect_to expense_upload_path(@upload.slug), notice: "File uploaded successfully."
    end
  rescue StandardError => e
    render :new, status: :unprocessable_entity
  end

  def show
    @transactions = @upload.expense_transactions.order(:transaction_date)
  end

  def destroy
    rescue_and_log(target: @upload) do
      @upload.destroy!
      redirect_to expense_uploads_path, notice: "Upload deleted."
    end
  rescue StandardError => e
    redirect_to expense_uploads_path, alert: e.message
  end

  def process_file
    rescue_and_log(target: @upload) do
      parser = Expenses::CsvParser.new(@upload)
      result = parser.parse

      date_range = @upload.expense_transactions.pick(
        Arel.sql("MIN(transaction_date)"), Arel.sql("MAX(transaction_date)")
      ) if result.transactions.any?

      @upload.update!(
        card_type: result.card_type || @upload.card_type,
        status: "processed",
        transaction_count: result.transactions.size,
        unique_transactions: result.transactions.size,
        duplicates_skipped: result.duplicates_skipped,
        credits_skipped: result.credits_skipped,
        first_transaction_at: date_range&.first,
        last_transaction_at: date_range&.last,
        processing_summary: {
          errors: result.errors,
          processed_at: Time.current.iso8601
        },
        processed_at: Time.current
      )

      notice = "Processed #{result.transactions.size} transactions"
      notice += " (#{result.duplicates_skipped} duplicates skipped)" if result.duplicates_skipped > 0
      notice += " (#{result.credits_skipped} credits skipped)" if result.credits_skipped > 0
      redirect_to expense_upload_path(@upload.slug), notice: notice
    end
  rescue StandardError => e
    redirect_to expense_upload_path(@upload.slug), alert: "Processing failed: #{e.message}"
  end

  def evaluate
    rescue_and_log(target: @upload) do
      @upload.update!(status: "evaluating")

      upload_id = @upload.id
      upload_slug = @upload.slug

      Thread.new do
        begin
          upload = ExpenseUpload.find_by(id: upload_id)
          evaluator = Expenses::AiEvaluator.new(upload)

          evaluator.evaluate do |progress|
            ActionCable.server.broadcast(
              "expense_evaluation_#{upload_slug}",
              { type: "progress", **progress }
            )
          end

          upload.update!(status: "evaluated", evaluated_at: Time.current)

          ActionCable.server.broadcast(
            "expense_evaluation_#{upload_slug}",
            { type: "complete" }
          )
        rescue StandardError => e
          ErrorLog.capture!(e)

          upload&.update_columns(status: "processed") if upload&.evaluating?

          ActionCable.server.broadcast(
            "expense_evaluation_#{upload_slug}",
            { type: "error", message: e.message }
          )
        ensure
          ActiveRecord::Base.connection_pool.release_connection
        end
      end

      redirect_to expense_upload_path(@upload.slug), notice: "AI evaluation started..."
    end
  rescue StandardError => e
    redirect_to expense_upload_path(@upload.slug), alert: "Evaluation failed: #{e.message}"
  end

  private

  def set_upload
    @upload = ExpenseUpload.find_by(slug: params[:slug])
    return redirect_to expense_uploads_path, alert: "Upload not found" unless @upload
  end
end
