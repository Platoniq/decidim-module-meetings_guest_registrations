# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::Admin::MeetingRegistrationsForm do
  subject(:form) { described_class.from_params(params).with_context(current_organization: meeting.organization, meeting:) }

  let(:meeting) { create(:meeting, :published) }
  let(:guest_registrations_enabled) { true }
  let(:privacy_text) { { en: "Privacy information" } }
  let(:params) do
    {
      registrations_enabled: true,
      available_slots: 10,
      reserved_slots: 0,
      registration_terms: { en: "Terms" },
      guest_registrations_enabled:,
      guest_registrations_privacy_text: privacy_text
    }
  end

  it { is_expected.to be_valid }

  context "without the privacy text" do
    let(:privacy_text) { { en: "" } }

    it { is_expected.not_to be_valid }

    context "when guest registrations are disabled" do
      let(:guest_registrations_enabled) { false }

      it { is_expected.to be_valid }
    end
  end

  context "when joining requires a verification" do
    before do
      meeting.organization.update!(available_authorizations: ["dummy_authorization_handler"])
      meeting.component.update!(permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
    end

    it "cannot enable guest registrations" do
      expect(form).not_to be_valid
      expect(form.errors[:guest_registrations_enabled]).to include(a_string_including("requires a verification"))
    end
  end
end
