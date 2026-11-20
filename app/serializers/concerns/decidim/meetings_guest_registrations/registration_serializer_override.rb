# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Exports guests with their own data. The core implementation reads
    # `resource.user.name`, so it is replaced instead of extended. Guest
    # registration form responses are linked through the session token stored
    # with the guest data.
    module RegistrationSerializerOverride
      def serialize
        {
          id: resource.id,
          code: resource.code,
          user: {
            name: resource.participant_name,
            email: resource.participant_email
          },
          phone: resource.participant_phone,
          registration_type: resource.guest? ? "guest" : "user",
          status: resource.status,
          registration_form_responses: serialize_responses
        }
      end

      private

      def serialize_responses
        return super unless resource.guest?

        questionnaire = resource.meeting.questionnaire
        guest = resource.guest_registration
        return [] if questionnaire.blank? || guest.blank?

        Decidim::Forms::UserResponsesSerializer.new(
          questionnaire.responses.where(user: nil, session_token: guest.session_token)
        ).serialize
      end
    end
  end
end
