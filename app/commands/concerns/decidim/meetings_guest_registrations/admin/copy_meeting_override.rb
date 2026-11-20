# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # Copies the guest registration settings with the rest of the
      # registration settings.
      module CopyMeetingOverride
        private

        def fields_from_meeting
          super.merge(
            guest_registrations_enabled: meeting.guest_registrations_enabled,
            guest_registrations_privacy_text: meeting.guest_registrations_privacy_text
          )
        end
      end
    end
  end
end
