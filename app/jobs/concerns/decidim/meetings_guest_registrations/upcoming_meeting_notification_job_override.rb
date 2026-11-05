# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Besides the followers, registered guests get the reminder by e-mail.
    module UpcomingMeetingNotificationJobOverride
      private

      def send_notification(meeting)
        super

        NotifyGuestsJob.notify_later(meeting, "reminder")
      end
    end
  end
end
