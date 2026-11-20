# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Adds the `join_as_guest` and `cancel_guest_registration` actions, and
    # closes the core registration actions to visitors without session.
    #
    # The core commands behind those actions look registrations up with
    # `user: current_user`. Without session that is `user: nil`, which matches
    # guest registrations: `leave` would destroy a guest registration and the
    # registration form responses of every guest.
    module MeetingPermissionsOverride
      private

      def can_join?
        user.present? && super
      end

      def can_join_waitlist?
        user.present? && super
      end

      def can_leave?
        user.present? && super
      end

      def can_decline_invitation?
        user.present? && super
      end

      def can_join_as_guest?
        user.nil? && meeting.present? && meeting.can_be_joined_by_guest?
      end

      # The guest registration comes from a signed cancellation token. A
      # registration cannot be cancelled once the meeting has started, nor
      # after the attendance has been validated.
      def can_cancel_guest_registration?
        guest_registration = context[:guest_registration]
        return false if meeting.blank? || guest_registration.blank?
        return false unless guest_registration.decidim_meeting_id == meeting.id

        guest_registration.cancellable?
      end
    end
  end
end
