Studio.configure do |config|
  config.app_name = "Tax Studio"
  config.session_key = :tax_user_id
  config.welcome_message = ->(user) { "Welcome to Tax Studio, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.configure_sso_user = ->(user) { user.role = "viewer" }
  config.theme_logos = [
    { file: "favicon.png", title: "Favicon" },
    { file: "logo.png",    title: "Navbar Logo" },
    { file: "logo.png",    title: "Auth Logo" },
  ]
  config.theme_primary = "#10B981"   # Emerald green
end
