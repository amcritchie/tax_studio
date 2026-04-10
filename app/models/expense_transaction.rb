class ExpenseTransaction < ApplicationRecord
  belongs_to :expense_upload

  before_validation :set_temp_slug, on: :create
  after_create :set_slug_from_id

  validates :transaction_date, :raw_description, :amount_cents, presence: true

  CATEGORIES = {
    "software_saas" => "Software / SaaS",
    "cloud_hosting" => "Cloud / Hosting",
    "ai_services" => "AI Services",
    "home_office" => "Home Office",
    "internet_phone" => "Internet / Phone",
    "professional_services" => "Professional Services",
    "education_research" => "Education / Research",
    "marketing_advertising" => "Marketing / Advertising",
    "travel" => "Travel",
    "meals_entertainment" => "Meals / Entertainment",
    "office_supplies" => "Office Supplies",
    "hardware_equipment" => "Hardware / Equipment",
    "domain_registration" => "Domain Registration",
    "banking_fees" => "Banking / Fees",
    "insurance" => "Insurance",
    "other_business" => "Other Business"
  }.freeze

  DEDUCTION_TYPES = {
    "operating_expense" => "Operating Expense",
    "startup_cost" => "Startup Cost"
  }.freeze

  ACCOUNTS = {
    "mcritchie_studio" => "McRitchie Studio",
    "turf_monster" => "Turf Monster",
    "personal" => "Personal"
  }.freeze

  STATUS_VALUES = %w[unreviewed classified needs_review reviewed].freeze

  scope :unreviewed, -> { where(status: "unreviewed") }
  scope :classified, -> { where(status: "classified") }
  scope :needs_review, -> { where(status: "needs_review") }
  scope :reviewed, -> { where(status: "reviewed") }
  scope :not_excluded, -> { where(excluded: false) }
  scope :business_expenses, -> { where(classification: "business_expense", excluded: false) }
  scope :with_exclude_reason, -> { where.not(exclude_reason: [nil, ""]) }
  scope :user_overridden, -> { where(excluded_by: "user").where.not(exclude_reason: [nil, ""]) }
  scope :recent, -> { order(transaction_date: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_account, ->(acc) { where(account: acc) }
  scope :by_card, ->(card) { where(payment_method: card) }
  scope :by_month, ->(month) { where("to_char(transaction_date, 'YYYY-MM') = ?", month) }

  def amount_dollars
    amount_cents / 100.0
  end

  def formatted_amount
    "$#{'%.2f' % amount_dollars}"
  end

  def category_display
    CATEGORIES[category] || category&.titleize
  end

  def deduction_type_display
    DEDUCTION_TYPES[deduction_type] || deduction_type&.titleize
  end

  def account_display
    ACCOUNTS[account] || account&.titleize
  end

  def business_expense?
    classification == "business_expense"
  end

  def needs_review?
    status == "needs_review"
  end

  def reviewed?
    status == "reviewed"
  end

  def to_param
    slug
  end

  private

  def set_temp_slug
    self.slug ||= "txn-#{SecureRandom.hex(4)}"
  end

  def set_slug_from_id
    update_column(:slug, "txn-#{id}")
  end

  def name_slug
    "txn-#{id}"
  end
end
