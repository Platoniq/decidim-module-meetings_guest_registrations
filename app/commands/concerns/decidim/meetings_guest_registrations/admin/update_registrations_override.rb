# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # Saves the guest registration settings of a meeting.
      module UpdateRegistrationsOverride
        protected

        def attributes
          extra = { guest_registrations_enabled: form.guest_registrations_active? }
          extra[:guest_registrations_privacy_text] = form.guest_registrations_privacy_text if form.guest_registrations_active?

          super.merge(extra)
        end
      end
    end
  end
end
