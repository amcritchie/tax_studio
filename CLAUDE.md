# Tax Studio

Standalone expense tracking satellite app — CSV parsing, AI classification, and tax reporting. Extracted from McRitchie Studio.

## Dev Server

- **Port 3003** — `bin/dev` or `bin/rails server -p 3003`
- McRitchie Studio (SSO hub) runs on port 3000

## Deployment

- **Heroku**: Not yet deployed (deferred)
- **Domain**: `tax.mcritchie.studio`
- **Repo**: https://github.com/amcritchie/tax_studio
- **Env vars needed**: `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `DATABASE_URL`, `ANTHROPIC_API_KEY`, `REDIS_URL` (for ActionCable)

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL
- Tailwind CSS via `tailwindcss-rails` gem (~2.7, compiled with `@apply` support)
- Alpine.js via CDN for interactivity
- ERB views, import maps, no JS frameworks
- ActiveStorage for CSV/XLSX file uploads
- ActionCable for real-time AI evaluation progress
- `roo` gem for XLSX parsing
- `redcarpet` gem for markdown rendering (expense guide)
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`

## Studio Engine

```ruby
Studio.configure do |config|
  config.app_name = "Tax Studio"
  config.session_key = :tax_user_id
  config.welcome_message = ->(user) { "Welcome to Tax Studio, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.configure_sso_user = ->(user) { user.role = "viewer" }
  config.theme_logos = %w[favicon.png logo.png]
  config.theme_primary = "#10B981"
end
```

**SSO Satellite Role:** Receives SSO from McRitchie Studio (hub) via shared session cookie. Login page shows "Continue as" button via engine partial. Same `SECRET_KEY_BASE` required across `*.mcritchie.studio`.

## Branding & Theme

- **Primary**: `#10B981` Emerald green
- **Logo**: "Tax **Studio**" (Studio in primary color)
- **Navbar**: Sticky, links to Uploads, Transactions, Summary, Tax Report, Guide. McRitchie Studio link for SSO hub. Admin dropdown with Payment Methods, Theme, Error Logs.

## Models

- **User** — name, first_name, last_name, email, password_digest, provider, uid, role (admin/viewer), slug. `has_secure_password`, `include Sluggable`. Same structure as McRitchie Studio's User model.
- **PaymentMethod** — name, slug (Sluggable), last_four, parser_key (maps to `CsvParser::CARD_PATTERNS`), color (hex), color_secondary (hex, optional), logo (path), position, status (active/inactive). `belongs_to :user`, `has_many :expense_uploads`. Scopes: `active`, `ordered`.
- **ExpenseUpload** — filename, slug (upload-{id}), card_type, status (pending/processed/evaluating/evaluated), transaction_count, unique_transactions, duplicates_skipped, credits_skipped, processing_summary (jsonb), first/last_transaction_at, payment_method_id (FK). `belongs_to :user`, `belongs_to :payment_method` (optional), `has_many :expense_transactions`, `has_one_attached :file`.
- **ExpenseTransaction** — slug (txn-{id}), transaction_date, raw_description, normalized_description, amount_cents, payment_method (string), AI classification fields (classification, category, deduction_type, account, vendor, business_description, business_purpose, ai_question, user_answer), status (unreviewed/classified/needs_review), exclude fields (excluded, exclude_reason, excluded_by, excluded_at). `belongs_to :expense_upload`.
- **ExpenseGuide** — content (markdown), slug. Singleton via `ExpenseGuide.current`. Provides classification rules fed to AI evaluator.
- **ErrorLog** — from studio engine.
- **ThemeSetting** — from studio engine.

## Services

- **Expenses::CsvParser** — Parses CSV/XLSX bank statements. Detects card format via `CARD_PATTERNS` (citi, capital_one_spark, chase, amex_platinum, robinhood) by scanning up to 20 rows for header patterns. Handles Amex XLSX metadata preamble. Auto-links PaymentMethod on detection. Deduplicates by normalized description + amount + date range.
- **Expenses::AiEvaluator** — Batch classifies transactions via Claude Haiku API. Processes in batches of 20 with ActionCable progress. Classifies as business_expense/not_business_expense/needs_review. `reclassify_with_answer` for needs_review follow-ups. **Important**: Requires `require "net/http"` at top of file — the Thread context doesn't autoload it.
- **Expenses::Exporter** — CSV export of business expenses.

## Channel

- **ExpenseEvaluationChannel** — streams `expense_evaluation_{upload_slug}` for real-time progress during AI evaluation.

## JS Modules (importmap)

- `expense_components` — registers `fileDrop` (drag-and-drop file upload) and `evaluationProgress` (ActionCable real-time progress tracker) Alpine.data components. `paymentMethodPicker` remains inline in `expense_uploads/new.html.erb` due to ERB interpolation of DB records.

## Routes

Simplified paths (whole app is expenses):
- `/` — Expense uploads index (root)
- `/uploads` — Uploads CRUD + process + evaluate
- `/uploads/new` — Upload with drag-and-drop + payment method picker
- `/uploads/:slug` — Upload detail with inline review for needs_review transactions
- `/transactions` — Filterable transaction list with status/category/account/card/month filters
- `/transactions/:slug` — Transaction detail with manual override form
- `/transactions/summary` — Expense summary by category/card/account/month
- `/transactions/tax_report` — Annual tax report with deduction breakdown
- `/transactions/export` — CSV export of business expenses
- `/guide` — Expense classification guide (preview + editor + generate from feedback)
- `/payment_methods` — Payment methods CRUD (admin)
- `/admin/theme`, `/error_logs` — From studio engine
- `/login`, `/signup`, `/logout`, `/sso_login` — Auth from studio engine

## Key Patterns

- **Upload pipeline**: pending → processed (CsvParser) → evaluating (AiEvaluator with ActionCable) → evaluated
- **Inline review**: needs_review transactions expand in the upload show view with AI question, answer input, category/account selects, approve/exclude buttons. Uses Alpine.js `inlineReview` component with JSON fetch to `/transactions/:slug.json`.
- **Exclude modal**: Shared modal component (`_exclude_modal.html.erb`) triggered by `open-exclude-modal` custom event. Requires a reason. Posts to `/transactions/:slug/toggle_exclude.json`.
- **Radio toggle**: Include/Exclude toggle on each transaction row (`_exclude_toggle.html.erb`). Visual state synced via `exclude-toggled` custom event.

## Error Handling

Same pattern as McRitchie Studio — see top-level `CLAUDE.md`.

- ExpenseUploadsController: create, destroy, process_file, evaluate all wrapped with `target: @upload`
- ExpenseTransactionsController: update, answer_review, toggle_exclude wrapped with `target: @transaction`
- ExpenseGuidesController: update, generate_from_feedback wrapped with `target: @guide`
- PaymentMethodsController: create, update, destroy wrapped with `target: @payment_method`

## Seeds

- 1 admin user: `alex@mcritchie.studio` / `password`
- 5 payment methods: Robinhood Gold, Capital One Spark (slug: "spark"), Capital One Savor (slug: "savor"), Chase Ink, Citi Double Cash. With logos in `public/payment_methods/`, brand colors, parser keys.
- ExpenseGuide.current (singleton with default classification rules)

## Public Assets

- `public/payment_methods/` — Card brand logos (robinhood.png/svg, capital-one.png/svg, capital-one-spark.png, chase.png/svg, citi.png/svg)

## Known Issues

- **`require "net/http"` needed**: Both `app/services/expenses/ai_evaluator.rb` and `app/controllers/expense_guides_controller.rb` must have `require "net/http"` at the top. The evaluate action runs in a Thread where Ruby's autoloader doesn't have `Net::HTTP` in scope.

## Testing

- No tests yet (freshly extracted app). Tests to be added as features stabilize.
- `bin/rails test` runs clean (0 tests, 0 failures).

## Workflow Preferences

Same as McRitchie Studio — see top-level `CLAUDE.md`.

## Session Protocol

When the user signals end of session, review and refactor ALL CLAUDE.md files to reflect current state.
