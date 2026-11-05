# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Guests promoted from the waiting list get an e-mail instead of a
    # notification. The core job promotes inside `meeting.with_lock`, so the
    # e-mail is enqueued after the commit.
    module PromoteFromWaitlistJobOverride
      private

      def notify_user(registration)
        return super unless registration.guest?
        return if registration.guest_registration.blank?

        guest_registration_id = registration.guest_registration.id
        MeetingsGuestRegistrations.after_commit do
          GuestRegistrationMailer.confirmation(guest_registration_id, promoted: true).deliver_later
        end
      end
    end
  end
end
