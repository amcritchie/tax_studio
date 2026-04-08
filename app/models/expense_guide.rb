class ExpenseGuide < ApplicationRecord
  before_validation :set_slug, on: :create

  validates :slug, presence: true, uniqueness: true

  DEFAULT_CONTENT = <<~MD
    # Expense Classification Guide

    ## Business Expense Rules
    - Software subscriptions used for development are business expenses
    - Cloud hosting, AI services, and domain registrations are business expenses
    - Home office expenses (internet, phone) are partially deductible
    - Hardware/equipment used for work is a business expense

    ## Not Business Expenses
    - Personal entertainment (Netflix, Spotify, gaming)
    - Groceries and personal meals
    - Personal clothing, personal travel
    - Gym memberships (unless business-related)

    ## Needs Review (Ambiguous)
    - Meals at restaurants (could be business meetings)
    - General Amazon purchases (could be office supplies or personal)
    - Phone bills (partial business use)
    - Mixed-use subscriptions

    ## Account Assignment
    - `mcritchie_studio` — Studio platform or general business ops
    - `turf_monster` — Turf Monster app expenses
    - `personal` — Not a business expense

    ## User Feedback Notes
    _This section is updated automatically from user exclude/include feedback._
  MD

  def self.current
    first || create!(slug: "expense-guide", content: DEFAULT_CONTENT)
  end

  def to_param
    slug
  end

  private

  def set_slug
    self.slug ||= "expense-guide"
  end
end
