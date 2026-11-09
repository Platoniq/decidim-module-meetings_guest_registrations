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

        # Decidim 0.32 bug: the core `send_notification` uses `meeting`, which
        # the command does not define, so marking a user as attendee raises a
        # NameError after saving the attendance.
        def meeting
          registration.meeting
        end
      end
    end
  end
end
