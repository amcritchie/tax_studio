namespace :expenses do
  desc "Backfill 'reviewed' status for user-excluded/overridden transactions"
  task backfill_reviewed: :environment do
    # Excluded + needs_review → reviewed (user excluded but AI status was never updated)
    count1 = ExpenseTransaction.where(excluded: true, status: "needs_review").update_all(status: "reviewed")
    puts "Updated #{count1} excluded+needs_review → reviewed"

    # Excluded + classified + excluded_by user → reviewed (user-excluded, not AI-excluded)
    count2 = ExpenseTransaction.where(excluded: true, status: "classified", excluded_by: "user").update_all(status: "reviewed")
    puts "Updated #{count2} excluded+classified+user → reviewed"

    puts "Done. Total updated: #{count1 + count2}"
  end
end
