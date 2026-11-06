# frozen_string_literal: true

require "spec_helper"

describe Decidim::StatsParticipantsCount do
  let(:organization) { create(:organization) }
  let(:space) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: space) }
  let(:meeting) { create(:meeting, :published, :with_registrations_enabled, component:, author: organization) }

  it "does not count guests" do
    create(:registration, meeting:)
    create_list(:guest_registration, 2, meeting:)

    expect(described_class.new(space).query).to eq(1)
  end
end
