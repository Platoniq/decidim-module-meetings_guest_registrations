# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Allows registrations without a user, backed by a GuestRegistration row.
    module RegistrationOverride
      extend ActiveSupport::Concern

      prepended do
        # The core declares `belongs_to :user` (required) and validates the
        # user uniqueness without allowing nil, which would reject a second
        # guest in the same meeting. Only those two validators are removed,
        # so validations added by other gems are kept.
        MeetingsGuestRegistrations::RegistrationOverride.remove_user_validators(self)

        belongs_to :user, foreign_key: "decidim_user_id", class_name: "Decidim::User", optional: true
        has_one :guest_registration,
                class_name: "Decidim::MeetingsGuestRegistrations::GuestRegistration",
                foreign_key: "decidim_meetings_registration_id",
                inverse_of: :registration,
                dependent: :destroy,
                autosave: true

        validates :user, uniqueness: { scope: :meeting }, allow_nil: true
        validate :user_xor_guest

        scope :guests, -> { where(decidim_user_id: nil) }
        scope :with_user, -> { where.not(decidim_user_id: nil) }
      end

      USER_VALIDATORS = [
        ActiveRecord::Validations::UniquenessValidator,
        ActiveRecord::Validations::PresenceValidator
      ].freeze

      def self.remove_user_validators(model)
        validators = model._validators[:user].select { |validator| USER_VALIDATORS.include?(validator.class) }
        return if validators.empty?

        model._validators = model._validators.merge(user: model._validators[:user] - validators)
        validators.each { |validator| model.skip_callback(:validate, :before, validator) }
      end

      def guest?
        decidim_user_id.nil?
      end

      def participant_name
        guest? ? guest_registration&.name : user&.name
      end

      def participant_email
        guest? ? guest_registration&.email : user&.email
      end

      def participant_phone
        guest_registration&.phone if guest?
      end

      private

      def user_xor_guest
        return if user.present? ^ guest_registration.present?

        errors.add(:base, :user_or_guest_required)
      end
    end
  end
end
