# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe GuestRegistration do
    subject(:guest) { create(:guest_registration, meeting:, email: "Ana@Example.org ") }

    let(:meeting) { create(:meeting, :published, :with_registrations_enabled) }

    it { is_expected.to be_valid }

    it "keeps the registration without a user" do
      expect(guest.registration).to be_guest
      expect(guest.registration.user).to be_nil
      expect(guest.registration.participant_email).to eq("Ana@Example.org")
    end

    it "stores the personal data encrypted" do
      raw = described_class.connection.select_one("SELECT name, email, phone FROM decidim_meetings_guest_registrations WHERE id = #{guest.id}")

      expect(raw["email"]).not_to include("Example.org")
      expect(raw["name"]).not_to eq(guest.name)
      expect(raw["phone"]).not_to include("600")
      expect(described_class.find(guest.id).email).to eq("Ana@Example.org")
    end

    it "stores a keyed digest of the normalized email" do
      expect(guest.email_digest).to eq(EmailDigest.call("ana@example.org"))
      expect(guest.email_digest).not_to eq(Digest::SHA256.hexdigest("ana@example.org"))
    end

    it "does not allow the same email twice in a meeting" do
      guest
      other = build(:guest_registration, meeting:, email: "ana@example.org")

      expect(other).not_to be_valid
      expect(other.errors[:email_digest]).to be_present
    end

    it "allows the same email in another meeting" do
      guest
      expect(build(:guest_registration, email: "ana@example.org")).to be_valid
    end

    it "removes line breaks from the name" do
      guest = create(:guest_registration, name: "Ana\r\nBcc: evil@example.org")

      expect(guest.reload.name).to eq("Ana Bcc: evil@example.org")
    end

    it "validates the email and phone format" do
      expect(build(:guest_registration, email: "not-an-email")).not_to be_valid
      expect(build(:guest_registration, phone: "abc")).not_to be_valid
    end

    describe "cancellation token" do
      it "finds the guest registration" do
        expect(described_class.find_by_token_for(:guest_cancellation, guest.cancellation_token)).to eq(guest)
      end

      it "stops working when the registration is destroyed" do
        token = guest.cancellation_token
        guest.registration.destroy!

        expect(described_class.find_by_token_for(:guest_cancellation, token)).to be_nil
      end

      it "rejects tampered tokens" do
        expect(described_class.find_by_token_for(:guest_cancellation, "#{guest.cancellation_token}x")).to be_nil
      end
    end

    it "is destroyed with its registration" do
      registration = guest.registration
      registration.destroy!

      expect(described_class.exists?(guest.id)).to be(false)
    end
  end
end
