Rails.application.routes.draw do
  scope :health, controller: :health do
    get :live
    get :ready
  end

  namespace :api do
    namespace :v1 do
      resources :registrations, only: :create
      resources :password_resets, only: :create
      # Any segment reaches the controller, which answers invalid_token for one it does not know.
      patch "password_resets/:token", to: "password_resets#update", as: :password_reset, constraints: { token: %r{[^/]+} }, format: false
      resources :sessions, only: %i[index create destroy], constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ } do
        collection do
          post :refresh
          delete :current, action: :destroy_current
        end
      end
      # Any lowercase purpose reaches the controller, which answers 404 for one it does not know.
      resources :consents, only: %i[index create destroy], param: :purpose, constraints: { purpose: /[a-z_]+/ }, format: false do
        get :text, on: :member
      end
      post "account/export", to: "accounts#export"
      delete "account", to: "accounts#destroy"
      get "profile", to: "profiles#show"
      patch "profile", to: "profiles#update"
      resources :sport_profiles, only: %i[index create destroy], constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
      post "foods/search", to: "foods#search"
      post "food_entries/uploads", to: "food_entry_uploads#create"
      get "food_entries/:id", to: "food_entries#show", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      post "food_entries/:id/analysis", to: "food_entry_analyses#create", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      get "food_entries", to: "food_entries#index", format: false
      post "food_entries", to: "food_entries#create", format: false
      delete "food_entries/:id", to: "food_entries#destroy", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      post "food_entries/:id/confirmation", to: "food_entries#confirm", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      post "food_entries/:id/items", to: "food_entry_items#create", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      patch "food_entries/:id/items/:item_id", to: "food_entry_items#update",
                                                     constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, item_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      delete "food_entries/:id/items/:item_id", to: "food_entry_items#destroy",
                                                     constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, item_id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      get "goal_types", to: "goal_types#index", format: false
      get "goals", to: "goals#index", format: false
      post "goals", to: "goals#create", format: false
      get "goals/history", to: "goal_history#index", format: false
      patch "goals/:id", to: "goals#update", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      delete "goals/:id", to: "goals#destroy", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      post "goals/:id/check_ins", to: "goal_check_ins#create", constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }, format: false
      delete "goals/:id/check_ins/:local_date", to: "goal_check_ins#destroy",
                                                constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, local_date: /\d{4}-\d{2}-\d{2}/ }, format: false
    end
  end

  # Operational probes for local development and tests. They never exist in production.
  if Rails.env.local?
    namespace :internal do
      resources :smoke_jobs, only: %i[create show], constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
      resources :smoke_errors, only: :create
    end
  end
end
