# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Registers a person without an account to a meeting, or puts them in the
    # waiting list when there are no slots left.
    #
    # It mirrors Decidim::Meetings::JoinMeeting and JoinWaitlist without the
    # parts that need a user: follows, gamification and notifications.
    class JoinMeetingAsGuest < Decidim::Command
      # Broadcasts:
      #   :ok, status        - :registered or :waiting_list. An email already
      #                        registered gets the same answer and an e-mail,
      #                        so the form does not reveal who is registered.
      #   :invalid_form      - form errors
      #   :invalid           - the meeting does not accept guests or has no room
      def initialize(meeting, form)
        @meeting = meeting
        @form = form
      end

      def call
        return broadcast(:invalid) unless meeting.can_be_joined_by_guest?
        return broadcast(:invalid_form) if form.invalid?

        result = register
        return already_registered if result == :already_registered
        return broadcast(result) unless result == :ok

        send_email
        notify_admins_over_percentage if registration.registered?

        broadcast(:ok, registration.status.to_sym)
      end

      private

      attr_reader :meeting, :form, :registration

      def register
        result = :ok

        meeting.with_lock do
          if !meeting.guest_can_take_a_place?
            result = :invalid
          elsif GuestRegistration.registered_with_email?(meeting, form.email)
            result = :already_registered
          elsif response_questionnaire == :invalid
            result = :invalid_form
          else
            create_registration!
          end
        end

        result
      rescue ActiveRecord::RecordNotUnique
        :already_registered
      end

      # Same answer a new registration would get right now. Only the owner of
      # the address learns, by e-mail, that it was already registered.
      def already_registered
        recipient = Recipient.encode_data(name: nil, email: form.email, locale: I18n.locale.to_s)
        mail = GuestRegistrationMailer.already_registered(meeting.id, recipient)
        MeetingsGuestRegistrations.after_commit { mail.deliver_later }

        broadcast(:ok, meeting.has_available_slots? ? :registered : :waiting_list)
      end

      def create_registration!
        @registration = Decidim::Meetings::Registration.new(
          meeting:,
          user: nil,
          public_participation: false,
          status: meeting.has_available_slots? ? :registered : :waiting_list
        )
        @registration.build_guest_registration(
          meeting:,
          name: form.name,
          email: form.email,
          phone: form.phone,
          locale: I18n.locale.to_s,
          session_token: form.context.session_token
        )
        @registration.save!
      end

      def response_questionnaire
        return unless questionnaire_required?

        Decidim::Forms::ResponseQuestionnaire.call(form, meeting.questionnaire) do
          on(:ok) { return :valid }
          on(:invalid) { return :invalid }
        end
      end

      def questionnaire_required?
        meeting.registration_form_enabled? && meeting.questionnaire.present? && meeting.questionnaire.questions.any?
      end

      def send_email
        mail = if registration.registered?
                 GuestRegistrationMailer.confirmation(registration.guest_registration.id)
               else
                 GuestRegistrationMailer.waitlist(registration.guest_registration.id)
               end
        MeetingsGuestRegistrations.after_commit { mail.deliver_later }
      end

      # Same thresholds as Decidim::Meetings::JoinMeeting.
      def notify_admins_over_percentage
        percentage = [0.5, 0.8, 1.0].find { |value| occupied_slots_over?(value) }
        return unless percentage

        Decidim::EventsManager.publish(
          event: "decidim.events.meetings.meeting_registrations_over_percentage",
          event_class: Decidim::Meetings::MeetingRegistrationsOverPercentageEvent,
          resource: meeting,
          affected_users: meeting.component.participatory_space.admins,
          extra: { percentage: }
        )
      end

      def occupied_slots_over?(percentage)
        meeting.remaining_slots == (meeting.available_slots * (1 - percentage)).round
      end
    end
  end
end
