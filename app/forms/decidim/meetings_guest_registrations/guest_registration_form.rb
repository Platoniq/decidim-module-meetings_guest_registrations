# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Form filled by a visitor without an account to register to a meeting.
    #
    # It extends the questionnaire form so the meeting registration form
    # (if any) is answered in the same page. `tos_agreement` is the
    # acceptance of the meeting registration terms.
    class GuestRegistrationForm < Decidim::Forms::QuestionnaireForm
      mimic :guest_registration

      attribute :name, String
      attribute :email, String
      attribute :phone, String
      attribute :privacy_agreement, Boolean

      validates :name, presence: true, length: { maximum: 150 }
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
      validates :phone, presence: true, format: { with: GuestRegistration::PHONE_FORMAT }
      validates :privacy_agreement, allow_nil: false, acceptance: true
      validate :email_not_registered

      # Guests never appear in the public list of attendees.
      def public_participation
        false
      end

      def email
        EmailDigest.normalize(super).presence
      end

      # `squish` also removes line breaks, which would make the SMTP delivery
      # fail ("To address may not contain CR or LF").
      def name
        super&.squish
      end

      def phone
        super&.strip
      end

      private

      def meeting
        context[:meeting]
      end

      def email_not_registered
        return if meeting.blank? || email.blank?
        return unless GuestRegistration.registered_with_email?(meeting, email)

        errors.add(:email, :taken)
      end
    end
  end
end
