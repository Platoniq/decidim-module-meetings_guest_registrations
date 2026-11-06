# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # Guests have no user to notify.
      module MarkAsAttendeeOverride
        protected

        def send_notification
          return if registration.user.blank?

          super
        end
      end
    end
  end
end
