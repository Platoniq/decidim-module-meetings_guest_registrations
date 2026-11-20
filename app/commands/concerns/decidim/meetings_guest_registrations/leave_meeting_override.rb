# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Second line of defence behind MeetingPermissionsOverride: without a user,
    # `Registration.find_by(meeting:, user: nil)` finds a guest registration and
    # `responses.where(user: nil)` matches the responses of every guest.
    module LeaveMeetingOverride
      def call
        return broadcast(:invalid) if @user.blank?

        super
      end
    end
  end
end
