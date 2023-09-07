module ActivityNotification
  # Controller to manage notifications API with Devise authentication.
  class NotificationsAPIWithDeviseController < NotificationsAPIController
    include DeviseTokenAuth::Concerns::SetUserByToken if defined?(DeviseTokenAuth)
    include DeviseAuthenticationController
  end
end