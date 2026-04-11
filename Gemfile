source "https://rubygems.org"

gem "rails", "~> 7.2.3", ">= 7.2.3.1"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

# Studio engine
gem "studio", git: "https://github.com/amcritchie/studio.git"

# CSV/XLSX parsing
gem "roo", "~> 2.10"

# Markdown rendering
gem "redcarpet"

# Environment variables
gem "dotenv-rails", groups: [:development, :test]

# Google OAuth
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# Password hashing
gem "bcrypt", "~> 3.1.7"

# ActionCable adapter (production)
gem "redis", "~> 5.0"

gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "error_highlight", ">= 0.4.0", platforms: [ :ruby ]
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
