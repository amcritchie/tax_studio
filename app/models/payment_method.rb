class PaymentMethod < ApplicationRecord
  include Sluggable

  belongs_to :user
  has_many :expense_uploads

  validates :name, presence: true

  STATUS_VALUES = %w[active inactive].freeze

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:position) }

  def active?
    status == "active"
  end

  def inactive?
    status == "inactive"
  end

  def display_name
    last_four.present? ? "#{name} ••••#{last_four}" : name
  end

  private

  def name_slug
    name.parameterize
  end
end
