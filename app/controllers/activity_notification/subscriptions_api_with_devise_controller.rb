module ActivityNotification
  # Controller to manage subscriptions API with Devise authentication.
  class SubscriptionsAPIWithDeviseController < SubscriptionsAPIController
    include DeviseTokenAuth::Concerns::SetUserByToken if defined?(DeviseTokenAuth)
    include DeviseAuthenticationController
  end
end