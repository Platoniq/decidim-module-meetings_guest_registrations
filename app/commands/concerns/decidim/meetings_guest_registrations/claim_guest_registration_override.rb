# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Prepended to Decidim::Meetings::JoinMeeting and JoinWaitlist.
    #
    # When a user joins a meeting where they already registered as a guest
    # with the same email, the user takes over that registration instead of
    # taking a second slot. It keeps its status, code and waiting list
    # position, and the guest data is removed.
    #
    # Guest emails are not verified, so rejecting the user would let anyone
    # lock them out by registering their email first.
    module ClaimGuestRegistrationOverride
      def call
        guest_registration = claimable_guest_registration
        return super if guest_registration.blank?

        return broadcast(:invalid) unless meeting.registrations_enabled?
        return broadcast(:invalid_form) unless form.valid?

        result = claim(guest_registration)
        return broadcast(result) unless result == :ok

        notify_claimed_registration
        broadcast(:ok)
      end

      private

      def claimable_guest_registration
        return if current_user.blank? || !current_user.confirmed?
        return if meeting.has_registration_for?(current_user)

        GuestRegistration.find_by(meeting:, email_digest: EmailDigest.call(current_user.email))
      end

      def claim(guest_registration)
        result = :ok

        meeting.with_lock do
          # It may have been cancelled since it was found.
          guest_registration = GuestRegistration.find_by(id: guest_registration.id)

          if guest_registration.nil?
            result = :invalid
          elsif response_registration_form == :invalid
            result = :invalid_form
          else
            remove_guest_responses(guest_registration)
            @registration = guest_registration.registration
            guest_registration.destroy!
            @registration.reload.update!(user: current_user, public_participation: form.public_participation)
          end
        end

        result
      end

      # The user responds the registration form as in the core, and the guest
      # responses are removed once the user ones are saved.
      def response_registration_form
        return unless registration_form?

        Decidim::Forms::ResponseQuestionnaire.call(form, meeting.questionnaire) do
          on(:ok) { return :valid }
          on(:invalid) { return :invalid }
        end
      end

      def remove_guest_responses(guest_registration)
        return unless registration_form?

        meeting.questionnaire.responses.where(user: nil, session_token: guest_registration.session_token).destroy_all
      end

      def registration_form?
        form.model_name == "questionnaire" && meeting.questionnaire.present?
      end

      # Same notifications as JoinMeeting and JoinWaitlist. The occupied slots
      # do not change, so the admins are not notified again.
      def notify_claimed_registration
        if @registration.registered?
          meeting.invites.find_by(user: current_user)&.accept!
          Decidim::Meetings::RegistrationMailer.confirmation(current_user, meeting, @registration).deliver_later
          publish_claimed_event("decidim.events.meetings.meeting_registration_confirmed", extra: { registration_code: @registration.code })
          Decidim::Gamification.increment_score(current_user, :attended_meetings)
          Decidim::CreateFollow.call(
            Decidim::FollowForm.from_params(followable_gid: meeting.to_signed_global_id.to_s).with_context(current_user:)
          )
        else
          publish_claimed_event("decidim.events.meetings.meeting_waitlist_added")
        end
      end

      def publish_claimed_event(event, extra: {})
        Decidim::EventsManager.publish(
          event:,
          event_class: Decidim::Meetings::MeetingRegistrationNotificationEvent,
          resource: meeting,
          affected_users: [current_user],
          extra:
        )
      end
    end
  end
end
