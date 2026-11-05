# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::Registration do
  let(:meeting) { create(:meeting, :published, :with_registrations_enabled) }
  let(:user) { create(:user, :confirmed, organization: meeting.organization) }

  it "is valid with a user" do
    expect(build(:registration, meeting:, user:)).to be_valid
  end

  it "is not valid without user and without guest data" do
    registration = build(:registration, meeting:, user: nil)

    expect(registration).not_to be_valid
    expect(registration.errors[:base]).to be_present
  end

  it "is not valid with a user and guest data" do
    registration = build(:registration, meeting:, user:)
    registration.build_guest_registration(meeting:, name: "Ana", email: "ana@example.org", phone: "600123456", locale: "en", session_token: "x")

    expect(registration).not_to be_valid
  end

  it "allows several guests in the same meeting" do
    create_list(:guest_registration, 2, meeting:)

    expect(meeting.registrations.guests.count).to eq(2)
  end

  it "still rejects the same user twice" do
    create(:registration, meeting:, user:)

    expect(build(:registration, meeting:, user:)).not_to be_valid
  end

  it "keeps the core code validation" do
    first = create(:registration, meeting:, user:)
    other = build(:registration, meeting:, user: create(:user, :confirmed, organization: meeting.organization), code: first.code)

    expect(other).not_to be_valid
    expect(other.errors[:code]).to be_present
  end

  it "still requires a meeting" do
    expect(build(:registration, meeting: nil, user:)).not_to be_valid
  end

  describe "scopes and participant data" do
    let!(:user_registration) { create(:registration, meeting:, user:) }
    let!(:guest) { create(:guest_registration, meeting:, name: "Ana Guest", email: "ana@example.org", phone: "+34 600 000 000") }

    it "splits guests and users" do
      expect(meeting.registrations.guests).to eq([guest.registration])
      expect(meeting.registrations.with_user).to eq([user_registration])
    end

    it "returns the participant data" do
      expect(guest.registration.participant_name).to eq("Ana Guest")
      expect(guest.registration.participant_phone).to eq("+34 600 000 000")
      expect(user_registration.participant_name).to eq(user.name)
      expect(user_registration.participant_email).to eq(user.email)
      expect(user_registration.participant_phone).to be_nil
    end
  end
end
