# Admin user
admin = User.find_or_create_by!(email: "alex@mcritchie.studio") do |u|
  u.name = "Alex McRitchie"
  u.password = "password"
  u.password_confirmation = "password"
  u.role = "admin"
end
puts "User: #{admin.name} [#{admin.role}]"

# Payment Methods
payment_methods_data = [
  { name: "Robinhood Gold",    slug: nil,     last_four: "9349", parser_key: "robinhood",         color: "#F8D180", color_secondary: nil, logo: "/payment_methods/robinhood.png",         position: 100 },
  { name: "Capital One Spark", slug: "spark", last_four: "5179", parser_key: "capital_one_spark", color: "#2F6D45", color_secondary: nil, logo: "/payment_methods/capital-one-spark.png", position: 200 },
  { name: "Capital One Savor", slug: "savor", last_four: "7867", parser_key: "capital_one_spark", color: "#9B503A", color_secondary: nil, logo: "/payment_methods/capital-one.png",       position: 300 },
  { name: "Chase Ink",         slug: nil,     last_four: "8895", parser_key: "chase",             color: "#72777D", color_secondary: nil, logo: "/payment_methods/chase.png",             position: 400 },
  { name: "Citi Double Cash",  slug: nil,     last_four: "5578", parser_key: "citi",              color: "#4794C8", color_secondary: nil, logo: "/payment_methods/citi.png",              position: 500 }
]

payment_methods_data.each do |data|
  pm = PaymentMethod.find_or_create_by!(name: data[:name]) do |p|
    p.user = admin
    p.last_four = data[:last_four]
    p.parser_key = data[:parser_key]
    p.color = data[:color]
    p.logo = data[:logo]
    p.position = data[:position]
  end
  pm.update!(color: data[:color], color_secondary: data[:color_secondary], logo: data[:logo], position: data[:position], parser_key: data[:parser_key]) if pm.color != data[:color] || pm.color_secondary != data[:color_secondary] || pm.logo != data[:logo] || pm.position != data[:position] || pm.parser_key != data[:parser_key]
  pm.update_column(:slug, data[:slug]) if data[:slug].present? && pm.slug != data[:slug]
  puts "PaymentMethod: #{pm.name} [#{pm.slug}] (#{pm.status})"
end

# Expense Guide
ExpenseGuide.current
puts "ExpenseGuide: #{ExpenseGuide.current.slug}"
