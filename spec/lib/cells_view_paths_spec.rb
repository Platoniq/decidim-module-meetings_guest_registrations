# frozen_string_literal: true

require "spec_helper"

describe "Cell view paths" do # rubocop:disable RSpec/DescribeClass
  let(:paths) { Cell::ViewModel.view_paths.map(&:to_s) }
  let(:module_path) { File.expand_path("app/cells", Decidim::MeetingsGuestRegistrations::Engine.root) }
  let(:meetings_path) { File.expand_path("app/cells", Decidim::Meetings::Engine.root) }
  let(:application_path) { Rails.root.join("app/cells").to_s }

  it "puts the module templates before the meetings ones" do
    expect(paths.index(module_path)).to be < paths.index(meetings_path)
  end

  it "lets the application override the module templates" do
    expect(paths.index(application_path)).to be < paths.index(module_path)
  end
end
