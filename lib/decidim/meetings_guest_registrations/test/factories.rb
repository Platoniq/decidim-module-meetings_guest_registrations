# frozen_string_literal: true

require "decidim/core/test/factories"
require "decidim/meetings/test/factories"

FactoryBot.define do
  factory :guest_registration, class: "Decidim::MeetingsGuestRegistrations::GuestRegistration" do
    transient do
      meeting { create(:meeting, :published, :with_registrations_enabled) }
      status { :registered }
    end

    name { Faker::Name.name }
    email { Faker::Internet.email }
    phone { "+34 600 123 456" }
    locale { "en" }
    session_token { SecureRandom.hex(16) }

    registration do
      build(:registration, meeting:, user: nil, status:, public_participation: false)
    end

    after(:build) do |guest, evaluator|
      guest.meeting = evaluator.meeting
      guest.registration.meeting = evaluator.meeting
      guest.registration.guest_registration = guest
    end
  end
end
