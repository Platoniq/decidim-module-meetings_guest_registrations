# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Name and e-mail come from the user or from the guest data.
    module RegistrationPresenterOverride
      def name
        __getobj__.participant_name
      end

      def email
        __getobj__.participant_email
      end

      def phone
        __getobj__.participant_phone
      end

      def registration_type
        I18n.t(__getobj__.guest? ? "guest" : "user", scope: "decidim.meetings_guest_registrations.registration_type")
      end
    end
  end
end
