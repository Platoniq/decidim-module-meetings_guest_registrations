# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Cancels a guest registration from the link in the guest e-mails. Same
    # logic as Decidim::Meetings::LeaveMeeting: the slot is released and the
    # waiting list is promoted. It is not possible once the meeting has
    # started or the attendance has been validated.
    class CancelGuestRegistration < Decidim::Command
      def initialize(guest_registration)
        @guest_registration = guest_registration
        @meeting = guest_registration&.meeting
      end

      def call
        return broadcast(:invalid) if guest_registration.blank? || meeting.blank?
        return broadcast(:invalid) unless guest_registration.cancellable?

        recipient = Recipient.encode(guest_registration)
        meeting_id = meeting.id

        meeting.with_lock do
          destroy_questionnaire_responses
          guest_registration.registration.destroy!
        end

        promote_from_waitlist!
        GuestRegistrationMailer.registration_cancelled(meeting_id, recipient).deliver_later

        broadcast(:ok)
      end

      private

      attr_reader :guest_registration, :meeting

      def destroy_questionnaire_responses
        questionnaire = meeting.questionnaire
        return if questionnaire.blank?

        questionnaire.responses.where(user: nil, session_token: guest_registration.session_token).destroy_all
      end

      # Enqueued after the lock is released and the deletion is committed, so
      # the job sees the free slot.
      # A withdrawn meeting does not promote anybody: the promoted people would
      # get no e-mail, because nothing is sent about inactive meetings.
      def promote_from_waitlist!
        meeting.reload
        return if meeting.withdrawn?
        return if meeting.available_slots.zero?
        return unless meeting.remaining_slots.positive?
        return unless meeting.registrations.on_waiting_list.exists?

        meeting_id = meeting.id
        MeetingsGuestRegistrations.after_commit { Decidim::Meetings::PromoteFromWaitlistJob.perform_later(meeting_id) }
      end
    end
  end
end
