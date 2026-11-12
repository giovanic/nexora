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
