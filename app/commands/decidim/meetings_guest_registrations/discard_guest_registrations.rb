# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Tells every guest that the meeting is cancelled and deletes their
    # registrations, personal data and registration form responses. Used when a
    # meeting is unpublished: if it is published again, guests have to
    # register again, as the cancellation e-mail told them.
    class DiscardGuestRegistrations < Decidim::Command
      def initialize(meeting)
        @meeting = meeting
      end

      def call
        meeting.with_lock do
          # Inside the transaction: the recipients are read before the
          # deletion, and the e-mails are only enqueued if it is committed.
          NotifyGuestsJob.notify_cancellation(meeting)

          NotifyGuestsJob.guests_of(meeting).find_each do |registration|
            destroy_responses(registration.guest_registration)
            registration.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :meeting

      def destroy_responses(guest_registration)
        questionnaire = meeting.questionnaire
        return if questionnaire.blank?

        questionnaire.responses.where(user: nil, session_token: guest_registration.session_token).destroy_all
      end
    end
  end
end
