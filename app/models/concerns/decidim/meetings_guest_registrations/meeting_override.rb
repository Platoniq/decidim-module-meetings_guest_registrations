# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Adds the guest registration settings to meetings.
    module MeetingOverride
      extend ActiveSupport::Concern

      # Actions whose verification requirements make guest registrations
      # impossible: a guest has no account to be verified.
      GUARDED_ACTIONS = %w(join join_waitlist).freeze

      prepended do
        translatable_fields(*translatable_fields_list, :guest_registrations_privacy_text)

        # Cancellation e-mails are sent before the meeting is trashed or
        # destroyed, because the registrations may be destroyed with it.
        before_destroy :notify_guests_of_cancellation, prepend: true
      end

      # Configuration level check: the meeting is set up to accept guests.
      def guest_registrations_allowed?
        guest_registrations_enabled? &&
          registrations_enabled? &&
          on_this_platform? &&
          !join_requires_verification?
      end

      # Whether a visitor without session can register right now.
      def can_be_joined_by_guest?
        guest_registrations_allowed? &&
          published? &&
          !withdrawn? &&
          !hidden? &&
          !started? &&
          can_participate?(nil)
      end

      # Whether a guest can take a place now: either a free slot or a place
      # in the waiting list.
      def guest_can_take_a_place?
        has_available_slots? || waitlist_enabled?
      end

      # True when the `join` (or `join_waitlist`) action asks for any
      # verification, at component or at resource level.
      def join_requires_verification?
        GUARDED_ACTIONS.any? { |action| action_requires_verification?(action) }
      end

      # The core implementation runs `registrations.where(user: nil)` for
      # visitors, which matches every guest registration.
      def has_registration_for?(user)
        return false if user.nil?

        super
      end

      private

      # Same lookup as Decidim::ActionAuthorizer: handlers that are not
      # available in the organization are not enforced, so they do not block
      # guests either.
      def action_requires_verification?(action)
        permission = permissions&.fetch(action, nil) || component&.permissions&.fetch(action, nil)
        return false if permission.blank?

        required_handlers(permission).intersect?(organization.available_authorizations.map(&:to_s))
      end

      def required_handlers(permission)
        return [permission["authorization_handler_name"].to_s] if permission["authorization_handler_name"].present?

        (permission["authorization_handlers"] || {}).keys.map(&:to_s)
      end

      def notify_guests_of_cancellation
        return unless published? && !withdrawn? && !past?

        NotifyGuestsJob.notify_cancellation(self)
      end
    end
  end
end
