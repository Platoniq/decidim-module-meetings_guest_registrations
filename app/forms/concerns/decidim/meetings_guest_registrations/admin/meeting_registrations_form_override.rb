# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    module Admin
      # Adds the guest registration settings to the meeting registrations form.
      module MeetingRegistrationsFormOverride
        extend ActiveSupport::Concern

        prepended do
          attribute :guest_registrations_enabled, :boolean, default: false
          translatable_attribute :guest_registrations_privacy_text, Decidim::Attributes::RichText

          validates :guest_registrations_privacy_text, translatable_presence: true, if: :guest_registrations_active?
          validate :guest_registrations_without_verifications, if: :guest_registrations_active?
        end

        def guest_registrations_active?
          registrations_enabled? && guest_registrations_enabled?
        end

        private

        def guest_registrations_without_verifications
          return if meeting.blank?
          return unless meeting.join_requires_verification?

          errors.add(:guest_registrations_enabled, :verification_required)
        end
      end
    end
  end
end
