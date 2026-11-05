# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::Permissions do
  subject { described_class.new(user, permission_action, context).permissions.allowed? }

  let(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           guest_registrations_enabled: true, guest_registrations_privacy_text: { en: "Privacy" })
  end
  let(:context) { { current_component: meeting.component, meeting: } }
  let(:permission_action) { Decidim::PermissionAction.new(scope: :public, action:, subject: :meeting) }
  let(:user) { nil }

  context "when joining as guest" do
    let(:action) { :join_as_guest }

    it { is_expected.to be(true) }

    context "with a user" do
      let(:user) { create(:user, :confirmed, organization: meeting.organization) }

      it { is_expected.to be(false) }
    end

    context "when the meeting does not allow guests" do
      before { meeting.update!(guest_registrations_enabled: false) }

      it { is_expected.to be(false) }
    end
  end
end
