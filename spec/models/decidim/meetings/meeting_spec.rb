# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::Meeting do
  subject(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           guest_registrations_enabled: true,
           guest_registrations_privacy_text: { en: "Privacy" })
  end

  describe "#guest_registrations_allowed?" do
    before { meeting.organization.update!(available_authorizations: ["dummy_authorization_handler"]) }

    it { is_expected.to be_guest_registrations_allowed }

    it "is false when the option is disabled" do
      meeting.update!(guest_registrations_enabled: false)
      expect(meeting).not_to be_guest_registrations_allowed
    end

    it "is false when registrations are disabled" do
      meeting.update!(registrations_enabled: false)
      expect(meeting).not_to be_guest_registrations_allowed
    end

    it "is false when registrations are on a different platform" do
      meeting.update!(registration_type: :on_different_platform, registration_url: "https://example.org")
      expect(meeting).not_to be_guest_registrations_allowed
    end

    context "when the component requires a verification to join" do
      before do
        meeting.component.update!(permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
      end

      it { is_expected.not_to be_guest_registrations_allowed }
    end

    context "when the required verification is not available in the organization" do
      before do
        meeting.component.update!(permissions: { "join" => { "authorization_handlers" => { "not_available_handler" => {} } } })
      end

      it { is_expected.to be_guest_registrations_allowed }
    end

    context "when the component requires a verification to join the waiting list" do
      before do
        meeting.component.update!(permissions: { "join_waitlist" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
      end

      it { is_expected.not_to be_guest_registrations_allowed }
    end

    context "when the meeting requires a verification to join" do
      before do
        meeting.component.update!(settings: { resources_permissions_enabled: true })
        Decidim::ResourcePermission.create!(resource: meeting, permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
        meeting.reload
      end

      it { is_expected.not_to be_guest_registrations_allowed }
    end
  end

  describe "#can_be_joined_by_guest?" do
    it { is_expected.to be_can_be_joined_by_guest }

    it "is false when the meeting has started" do
      meeting.update!(start_time: 1.hour.ago, end_time: 1.hour.from_now)
      expect(meeting).not_to be_can_be_joined_by_guest
    end

    it "is false for private meetings" do
      meeting.update!(private_meeting: true, transparent: false)
      expect(meeting).not_to be_can_be_joined_by_guest
    end
  end

  describe "#has_registration_for?" do
    before { create(:guest_registration, meeting:) }

    it "is false for visitors even if there are guests" do
      expect(meeting.has_registration_for?(nil)).to be(false)
    end
  end

  it "keeps the privacy text translatable" do
    expect(meeting.guest_registrations_privacy_text["en"]).to eq("Privacy")
  end

  it "keeps public participants out of guests" do
    create(:guest_registration, meeting:)
    expect(meeting.public_participants).to be_empty
  end
end
