class ExpenseEvaluationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "expense_evaluation_#{params[:upload_slug]}"
  end
end
