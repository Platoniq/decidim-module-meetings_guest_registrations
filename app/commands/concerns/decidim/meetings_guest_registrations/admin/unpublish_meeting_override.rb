# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # An unpublished meeting is cancelled for its guests: they are told so and
      # their registrations are deleted, so a later republication does not
      # bring back people who were told the meeting was cancelled. This also
      # happens while the component or the space is unpublished.
      module UnpublishMeetingOverride
        def call
          was_active = NotifyGuestsJob.meeting_active?(meeting) && !meeting.past?

          super.tap do
            DiscardGuestRegistrations.call(meeting) if was_active && !meeting.reload.published?
          end
        end
      end
    end
  end
end
