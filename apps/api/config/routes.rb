Rails.application.routes.draw do
  scope :health, controller: :health do
    get :live
    get :ready
  end

  # Operational probes for local development and tests. They never exist in production.
  if Rails.env.local?
    namespace :internal do
      resources :smoke_jobs, only: %i[create show], constraints: { id: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
      resources :smoke_errors, only: :create
    end
  end
end
