# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # A withdrawn meeting is cancelled from the guests point of view.
    module WithdrawMeetingOverride
      private

      def change_meeting_state_to_withdrawn
        notify = @meeting.published? && !@meeting.withdrawn? && !@meeting.past?

        super.tap do
          NotifyGuestsJob.notify_cancellation(@meeting) if notify && @meeting.withdrawn?
        end
      end
    end
  end
end
