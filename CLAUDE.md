# Tax Studio

Standalone expense tracking satellite app — CSV parsing, AI classification, and tax reporting. Extracted from McRitchie Studio.

## Dev Server

- **Port 3003** — `bin/dev` or `bin/rails server -p 3003`
- McRitchie Studio (SSO hub) runs on port 3000

## Deployment

- **Heroku**: Not yet deployed (deferred)
- **Domain**: `tax.mcritchie.studio`
- **Repo**: https://github.com/amcritchie/tax_studio
- **Env vars needed**: `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `DATABASE_URL`, `ANTHROPIC_API_KEY`, `REDIS_URL` (for ActionCable), `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL
- Tailwind CSS via `tailwindcss-rails` gem (~2.7, compiled with `@apply` support)
- Alpine.js via CDN for interactivity
- ERB views, import maps, no JS frameworks
- ActiveStorage for CSV/XLSX file uploads
- ActionCable for real-time AI evaluation progress
- `roo` gem for XLSX parsing
- `redcarpet` gem for markdown rendering (expense guide)
- Google OAuth via `omniauth-google-oauth2` + `omniauth-rails_csrf_protection` gems
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`

## Studio Engine

```ruby
Studio.configure do |config|
  config.app_name = "Tax Studio"
  config.session_key = :tax_user_id
  config.welcome_message = ->(user) { "Welcome to Tax Studio, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.configure_sso_user = ->(user) { user.role = "viewer" }
  config.theme_logos = [
    { file: "favicon.png",  title: "Favicon" },
    { file: "logo.png",     title: "Navbar Logo" },
    { file: "logo.png",     title: "Auth Logo" },
  ]
  config.theme_primary = "#10B981"
end
```

**SSO Satellite Role:** Receives SSO from McRitchie Studio (hub) via shared session cookie. Login page shows "Continue as" button via engine partial. Same `SECRET_KEY_BASE` required across `*.mcritchie.studio`.

## Branding & Theme

- **Primary**: `#10B981` Emerald green
- **Logo**: "Tax **Studio**" (Studio in primary color)
- **Navbar**: Extracted to `layouts/_navbar.html.erb` — sticky with scroll hysteresis (Alpine.js), logo via `Studio.logo_for("Navbar Logo")`, brand title auto-split ("Tax **Studio**"), full nav links (Uploads, Transactions, Summary, Tax Report, Guide), McRitchie Studio link for SSO hub, mobile sub-navbar, admin dropdown with Payment Methods, Navbar, Theme, Error Logs.

## Models

- **User** — name, first_name, last_name, email, password_digest, provider, uid, role (admin/viewer), slug. `has_secure_password`, `include Sluggable`. Same structure as McRitchie Studio's User model.
- **PaymentMethod** — name, slug (Sluggable), last_four, parser_key (maps to `CsvParser::CARD_PATTERNS`), color (hex), color_secondary (hex, optional), logo (path), position, status (active/inactive). `belongs_to :user`, `has_many :expense_uploads`. Scopes: `active`, `ordered`.
- **ExpenseUpload** — filename, slug (upload-{id}), card_type, status (pending/processed/evaluating/evaluated), transaction_count, unique_transactions, duplicates_skipped, credits_skipped, processing_summary (jsonb), first/last_transaction_at, payment_method_id (FK). `belongs_to :user`, `belongs_to :payment_method` (optional), `has_many :expense_transactions`, `has_one_attached :file`.
- **ExpenseTransaction** — slug (txn-{id}), transaction_date, raw_description, normalized_description, amount_cents, payment_method (string), AI classification fields (classification, category, deduction_type, account, vendor, business_description, business_purpose, ai_question, user_answer), status (unreviewed/classified/needs_review/reviewed), manually_overridden (boolean), exclude fields (excluded, exclude_reason, excluded_by, excluded_at). `belongs_to :expense_upload`. Status `reviewed` = user has taken action (manual override, exclude, or include). `classified` = AI-set only.
- **ExpenseGuide** — content (markdown), slug. Singleton via `ExpenseGuide.current`. Provides classification rules fed to AI evaluator.
- **ErrorLog** — from studio engine.
- **ThemeSetting** — from studio engine.

## Services

- **Expenses::CsvParser** — Parses CSV/XLSX bank statements. Detects card format via `CARD_PATTERNS` (citi, capital_one_spark, chase, amex_platinum, robinhood) by scanning up to 20 rows for header patterns. Handles Amex XLSX metadata preamble. Auto-links PaymentMethod on detection. Deduplicates by normalized description + amount + date range.
- **Expenses::AiEvaluator** — Batch classifies transactions via Claude Haiku API. Processes in batches of 20 with ActionCable progress. Classifies as business_expense/not_business_expense/needs_review. `evaluate_single(transaction)` for re-evaluating one transaction. `reclassify_with_answer` for needs_review follow-ups. **Important**: Requires `require "net/http"` at top of file — the Thread context doesn't autoload it.
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
- `/transactions/:slug` — Transaction detail with manual override form + re-evaluate button
- `/transactions/:slug/re_evaluate` — POST: reset and re-run AI classification on a single transaction
- `/transactions/summary` — Expense summary by category/card/account/month
- `/transactions/tax_report` — Annual tax report with deduction breakdown
- `/transactions/export` — CSV export of business expenses
- `/guide` — Expense classification guide (preview + editor + generate from feedback)
- `/payment_methods` — Payment methods CRUD (admin)
- `/admin/theme`, `/admin/navbar`, `/error_logs` — From studio engine (navbar route added locally)
- `/login`, `/signup`, `/logout`, `/sso_login` — Auth from studio engine
- `/auth/google_oauth2/callback` — Google OAuth callback from studio engine

## Key Patterns

- **Upload pipeline**: pending → processed (CsvParser) → evaluating (AiEvaluator with ActionCable) → evaluated
- **Transaction status lifecycle**: `unreviewed` → AI sets `classified` or `needs_review` → user action (manual override, exclude, include, approve) sets `reviewed`. Re-evaluate resets to `unreviewed` then AI re-classifies. Badge colors: unreviewed=warning, classified+business=emerald, classified+personal=gray, needs_review=orange, reviewed=violet.
- **Inline review**: needs_review transactions expand in the upload show view with AI question, answer input, category/account selects, approve/exclude buttons. Uses Alpine.js `inlineReview` component with JSON fetch to `/transactions/:slug.json`.
- **Exclude modal**: Shared modal component (`_exclude_modal.html.erb`) triggered by `open-exclude-modal` custom event. Reason required (server-side validated). Quick-select dropdown with presets (Personal Dining, Personal Travel, Entertainment, Health, Groceries, Home Expense, Discretionary, Gifts, Vacation) for excludes. Posts to `/transactions/:slug/toggle_exclude.json`. Excluding auto-sets account to "personal" and status to "reviewed"; re-including also sets status to "reviewed".
- **Re-evaluate**: Icon button on classified/reviewed transaction rows (upload show + transaction show). Resets all AI fields, calls `AiEvaluator#evaluate_single`, returns fresh classification. Confirmation dialog before submitting.
- **Batch exclude**: On upload show page, modal receives `vendor_slugs` local (vendor→slugs lookup via `data-` attribute). Shows "Update X similar transactions" checkbox when other non-excluded transactions share the same vendor. Batch-submits to each matching transaction.
- **Radio toggle**: Include/Exclude toggle on each transaction row (`_exclude_toggle.html.erb`). Visual state synced via `exclude-toggled` custom event.
- **Google search**: Each transaction row in upload show has a search icon linking to Google search of the raw description (opens in new tab).

## Error Handling

Same pattern as McRitchie Studio — see top-level `CLAUDE.md`.

- ExpenseUploadsController: create, destroy, process_file, evaluate all wrapped with `target: @upload`
- ExpenseTransactionsController: update, answer_review, toggle_exclude, re_evaluate wrapped with `target: @transaction`
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
