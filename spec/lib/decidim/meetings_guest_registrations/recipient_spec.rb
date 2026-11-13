# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe Recipient do
    let(:guest) { build(:guest_registration, name: "Ana", email: "ana@example.org", locale: "ca") }

    it "decodes what it encodes" do
      expect(described_class.decode(described_class.encode(guest))).to eq(name: "Ana", email: "ana@example.org", locale: "ca")
    end

    it "does not carry the data in clear" do
      expect(described_class.encode(guest)).not_to include("ana@example.org")
    end

    it "ignores a payload that is not encrypted by us" do
      expect(described_class.decode("tampered")).to be_nil
    end

    it "ignores an encrypted payload that is not a recipient" do
      expect(described_class.decode(Decidim::AttributeEncryptor.encrypt("[1,2]"))).to be_nil
    end
  end
end
