import "@hotwired/turbo-rails"
import "controllers"
import { createConsumer } from "@rails/actioncable"
import "expense_components"

window.cable = createConsumer()
