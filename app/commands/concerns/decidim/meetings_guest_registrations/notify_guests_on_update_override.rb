# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Used by Decidim::Meetings::UpdateMeeting and
    # Decidim::Meetings::Admin::UpdateMeeting. Both call `send_notification`
    # only when `should_notify_followers?` is true, that is, when one of their
    # `important_attributes` changed, so guests are told about the same changes
    # as followers.
    module NotifyGuestsOnUpdateOverride
      private

      def send_notification
        super

        meeting_record = respond_to?(:resource, true) ? resource : meeting
        return unless meeting_record.published?

        NotifyGuestsJob.notify_later(meeting_record, "meeting_updated")
      end
    end
  end
end
