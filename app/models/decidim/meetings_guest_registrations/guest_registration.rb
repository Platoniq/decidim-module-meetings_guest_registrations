# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Personal data of a person registered to a meeting without an account.
    # There is one row per guest `Decidim::Meetings::Registration`; capacity,
    # waiting list, codes and attendance stay in the registration.
    class GuestRegistration < ApplicationRecord
      include Decidim::RecordEncryptor

      PHONE_FORMAT = /\A\+?[0-9][0-9\s().-]{5,24}\z/

      self.table_name = "decidim_meetings_guest_registrations"

      belongs_to :registration,
                 class_name: "Decidim::Meetings::Registration",
                 foreign_key: "decidim_meetings_registration_id",
                 inverse_of: :guest_registration
      belongs_to :meeting,
                 class_name: "Decidim::Meetings::Meeting",
                 foreign_key: "decidim_meeting_id"

      encrypt_attribute :name, type: :string
      encrypt_attribute :email, type: :string
      encrypt_attribute :phone, type: :string

      before_validation :normalize_personal_data
      before_validation :compute_email_digest

      validates :name, :email, :phone, :locale, :session_token, presence: true
      validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
      validates :phone, format: { with: PHONE_FORMAT }, allow_blank: true
      validates :email_digest, uniqueness: { scope: :decidim_meeting_id }, allow_blank: true

      # The token embeds the record id and the email digest, so it stops being
      # valid once the registration is destroyed.
      generates_token_for :guest_cancellation do
        email_digest
      end

      delegate :organization, to: :meeting

      def self.registered_with_email?(meeting, email)
        digest = EmailDigest.call(email)
        return false if digest.blank?

        exists?(meeting:, email_digest: digest)
      end

      def cancellation_token
        generate_token_for(:guest_cancellation)
      end

      # Same rule as the core "cancel registration" button, which disappears
      # once the meeting has started. A validated attendance is not undone.
      def cancellable?
        meeting.present? && !meeting.started? && registration.present? && !registration.validated?
      end

      private

      def normalize_personal_data
        self.name = name.squish if name.is_a?(String)
        self.email = email.strip if email.is_a?(String)
        self.phone = phone.strip if phone.is_a?(String)
      end

      def compute_email_digest
        self.email_digest = EmailDigest.call(email)
      end
    end
  end
end
