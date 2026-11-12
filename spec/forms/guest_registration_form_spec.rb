# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe GuestRegistrationForm do
    subject(:form) { described_class.from_params(params).with_context(meeting:, session_token: "token") }

    let(:meeting) { create(:meeting, :published, :with_registrations_enabled) }
    let(:params) do
      { name: " Ana ", email: " ANA@Example.org ", phone: "600 123 456", privacy_agreement: "1", tos_agreement: "1", public_participation: "1" }
    end

    it { is_expected.to be_valid }

    it "normalizes the data" do
      expect(form.name).to eq("Ana")
      expect(form.email).to eq("ana@example.org")
    end

    it "removes line breaks from the name" do
      params[:name] = "Ana\r\nBcc: evil@example.org"

      expect(form.name).to eq("Ana Bcc: evil@example.org")
    end

    it "never makes the participation public" do
      expect(form.public_participation).to be(false)
    end

    [:name, :email, :phone].each do |attribute|
      it "requires #{attribute}" do
        params[attribute] = ""
        expect(form).not_to be_valid
      end
    end

    it "requires the privacy agreement" do
      params[:privacy_agreement] = "0"
      expect(form).not_to be_valid
    end

    it "requires the registration terms" do
      params[:tos_agreement] = "0"
      expect(form).not_to be_valid
    end

    it "rejects an email already registered" do
      create(:guest_registration, meeting:, email: "ana@example.org")
      expect(form).not_to be_valid
      expect(form.errors[:email]).to be_present
    end

    it "rejects the email of a user registered to the meeting" do
      user = create(:user, :confirmed, organization: meeting.organization, email: "ana@example.org")
      create(:registration, meeting:, user:)

      expect(form).not_to be_valid
      expect(form.errors.details[:email]).to include(error: :taken)
    end

    it "accepts the email of a user registered to another meeting" do
      user = create(:user, :confirmed, organization: meeting.organization, email: "ana@example.org")
      create(:registration, user:)

      expect(form).to be_valid
    end
  end
end
