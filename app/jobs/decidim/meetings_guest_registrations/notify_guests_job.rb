# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Sends one e-mail per guest of a meeting about changes in the meeting and
    # the reminder before it starts. Nothing is sent for meetings that are no
    # longer active (unpublished, withdrawn, hidden or trashed), because their
    # guests have already been told that the meeting is cancelled, nor while
    # its component or participatory space is unpublished.
    class NotifyGuestsJob < ApplicationJob
      queue_as :mailers

      KINDS = {
        "meeting_updated" => %w(registered waiting_list),
        "reminder" => %w(registered)
      }.freeze

      def perform(meeting_id, kind)
        statuses = KINDS.fetch(kind.to_s)
        meeting = Decidim::Meetings::Meeting.find_by(id: meeting_id)
        return unless self.class.notifiable?(meeting)

        self.class.guests_of(meeting).where(status: statuses).find_each do |registration|
          GuestRegistrationMailer.public_send(kind, registration.guest_registration.id).deliver_later
        end
      end

      # Enqueues the job once the current transaction (if any) is committed,
      # so it reads the saved meeting and is not enqueued on a rollback.
      def self.notify_later(meeting, kind)
        meeting_id = meeting.id
        MeetingsGuestRegistrations.after_commit { perform_later(meeting_id, kind.to_s) }
      end

      # Tells every guest that the meeting is cancelled. The recipients are
      # read now, because the registrations may be destroyed together with
      # the meeting, and the e-mails are enqueued after the commit.
      def self.notify_cancellation(meeting)
        meeting_id = meeting.id
        recipients = guests_of(meeting).map { |registration| Recipient.encode(registration.guest_registration) }
        return if recipients.empty?

        MeetingsGuestRegistrations.after_commit do
          recipients.each { |recipient| GuestRegistrationMailer.meeting_cancelled(meeting_id, recipient).deliver_later }
        end
      end

      def self.guests_of(meeting)
        meeting.registrations.guests.joins(:guest_registration).includes(:guest_registration)
      end

      # The state of the meeting itself. Once it is not active, its guests have
      # been told that it is cancelled, so nothing else is sent about it. It
      # does not look at the component or the space: it decides whether the
      # meeting is cancelled for guests and whether they get the e-mails about
      # their own registration.
      def self.meeting_active?(meeting)
        meeting.present? && meeting.published? && !meeting.withdrawn? && !meeting.hidden? && !meeting.deleted?
      end

      # Whether the changes and the reminder are sent: same filter as
      # Decidim::EventPublisherJob#notifiable? (which keeps the followers from
      # being notified), plus the meeting own state. An unpublished space or
      # component is taken as temporary: no cancellation is sent, these
      # e-mails just stop.
      def self.notifiable?(meeting)
        return false unless meeting_active?(meeting)
        return false unless meeting.component&.published?

        space = meeting.participatory_space
        !(space.is_a?(Decidim::Publicable) && !space.published?)
      end
    end
  end
end
