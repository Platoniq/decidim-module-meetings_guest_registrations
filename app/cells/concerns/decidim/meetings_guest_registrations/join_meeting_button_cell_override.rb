# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Visitors without session go to the guest form when the meeting allows it.
    module JoinMeetingButtonCellOverride
      def show
        return render if guest_registration_available?

        super
      end

      def guest_registration_available?
        current_user.blank? && model.can_be_joined_by_guest? && model.guest_can_take_a_place?
      end

      def render_waitlist_button?
        return model.waitlist_enabled? && !model.has_available_slots? if guest_registration_available?

        super
      end

      private

      def guest_registration_path
        new_meeting_guest_registration_path(meeting_id: model.id)
      end
    end
  end
end
