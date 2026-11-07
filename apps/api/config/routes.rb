Rails.application.routes.draw do
  scope :health, controller: :health do
    get :live
    get :ready
  end
end
