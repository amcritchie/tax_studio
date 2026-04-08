Rails.application.routes.draw do
  Studio.routes(self)

  root "expense_uploads#index"

  resources :payment_methods, param: :slug, except: [:show]

  resources :expense_uploads, path: "uploads", param: :slug, only: [:index, :new, :create, :show, :destroy] do
    member do
      post :process_file
      post :evaluate
    end
  end

  resource :expense_guide, path: "guide", only: [:show, :update] do
    post :generate_from_feedback, on: :member
  end

  resources :expense_transactions, path: "transactions", param: :slug, only: [:index, :show, :update] do
    member do
      post :answer_review
      post :toggle_exclude
    end
    collection do
      get :export
      get :summary
      get :tax_report
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
