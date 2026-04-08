class PaymentMethodsController < ApplicationController
  before_action :require_admin
  before_action :set_payment_method, only: [:edit, :update, :destroy]

  def index
    @payment_methods = PaymentMethod.ordered
  end

  def new
    @payment_method = PaymentMethod.new
  end

  def create
    @payment_method = PaymentMethod.new(payment_method_params)
    @payment_method.user = current_user
    rescue_and_log(target: @payment_method) do
      @payment_method.save!
      redirect_to payment_methods_path, notice: "Payment method created."
    end
  rescue StandardError => e
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    rescue_and_log(target: @payment_method) do
      @payment_method.update!(payment_method_params)
      redirect_to payment_methods_path, notice: "Payment method updated."
    end
  rescue StandardError => e
    render :edit, status: :unprocessable_entity
  end

  def destroy
    rescue_and_log(target: @payment_method) do
      @payment_method.destroy!
      redirect_to payment_methods_path, notice: "Payment method deleted."
    end
  rescue StandardError => e
    redirect_to payment_methods_path, alert: e.message
  end

  private

  def set_payment_method
    @payment_method = PaymentMethod.find_by(slug: params[:slug])
    return redirect_to payment_methods_path, alert: "Payment method not found" unless @payment_method
  end

  def payment_method_params
    params.require(:payment_method).permit(:name, :last_four, :parser_key, :color, :color_secondary, :logo, :position, :status)
  end
end
