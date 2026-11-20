# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # Guests have no user to notify.
      module ValidateRegistrationCodeOverride
        private

        def send_notification
          return if form.registration.user.blank?

          super
        end
      end
    end
  end
end
