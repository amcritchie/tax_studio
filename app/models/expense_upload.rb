class ExpenseUpload < ApplicationRecord
  belongs_to :user
  belongs_to :payment_method, optional: true
  has_many :expense_transactions, dependent: :destroy
  has_one_attached :file

  before_validation :set_temp_slug, on: :create
  after_create :set_slug_from_id

  validates :filename, presence: true

  STATUS_VALUES = %w[pending processed evaluating evaluated].freeze

  scope :recent, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def processed?
    status == "processed"
  end

  def evaluating?
    status == "evaluating"
  end

  def evaluated?
    status == "evaluated"
  end

  def card_type_display
    payment_method&.name || card_type&.titleize || "Unknown"
  end

  def to_param
    slug
  end

  private

  def set_temp_slug
    self.slug ||= "upload-#{SecureRandom.hex(4)}"
  end

  def set_slug_from_id
    update_column(:slug, "upload-#{id}")
  end

  def name_slug
    "upload-#{id}"
  end
end
