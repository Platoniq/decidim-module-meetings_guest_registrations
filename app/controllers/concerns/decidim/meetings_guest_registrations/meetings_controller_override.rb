# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # The core looks for `registrations.find_by(user: current_user)`, which
    # for visitors matches a guest registration and would show its code and QR.
    module MeetingsControllerOverride
      private

      def registration
        return if current_user.blank?

        super
      end
    end
  end
end
