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
      get "profile", to: "profiles#show"
      patch "profile", to: "profiles#update"
      resources :sport_profiles, only: %i[index create destroy], constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
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
