# frozen_string_literal: true

require "spec_helper"

describe "Admin manages guest registrations" do
  let(:manifest_name) { "meetings" }
  let!(:meeting) do
    create(:meeting, :published, component: current_component, registrations_enabled: true, available_slots: 10, reserved_slots: 0,
                                 registration_terms: { en: "Terms" })
  end

  include_context "when managing a component as an admin"

  def edit_registrations_path
    Decidim::EngineRouter.admin_proxy(current_component).edit_meeting_registrations_path(meeting_id: meeting.id)
  end

  it "enables guest registrations" do
    visit edit_registrations_path

    check "Allow registrations without an account"
    fill_in_i18n_editor(
      :meeting_guest_registrations_privacy_text,
      "#meeting-guest_registrations_privacy_text-tabs",
      en: "Data protection",
      es: "Protección de datos",
      ca: "Protecció de dades"
    )
    click_on "Save"

    expect(page).to have_admin_callout("Meeting registrations settings successfully saved")
    expect(meeting.reload.guest_registrations_enabled).to be(true)
  end

  it "requires the privacy text" do
    visit edit_registrations_path

    check "Allow registrations without an account"
    click_on "Save"

    expect(page).to have_admin_callout("There was a problem saving the registration settings")
    expect(meeting.reload.guest_registrations_enabled).to be(false)
  end

  context "when joining requires a verification" do
    before do
      current_component.update!(permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
    end

    it "cannot enable guest registrations" do
      visit edit_registrations_path

      check "Allow registrations without an account"
      fill_in_i18n_editor(:meeting_guest_registrations_privacy_text, "#meeting-guest_registrations_privacy_text-tabs", en: "Data protection")
      click_on "Save"

      expect(page).to have_content("requires a verification")
      expect(meeting.reload.guest_registrations_enabled).to be(false)
    end
  end

  context "when the option is enabled but a verification was added later" do
    before do
      meeting.update!(guest_registrations_enabled: true, guest_registrations_privacy_text: { en: "Privacy" })
      current_component.update!(permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } })
    end

    it "warns the admin" do
      visit edit_registrations_path

      expect(page).to have_content("Registrations without an account are enabled, but they are not working")
    end
  end

  context "with guests registered" do
    let!(:guest) { create(:guest_registration, meeting:, name: "Ana Guest", email: "ana@example.org", phone: "+34 600 123 456") }
    let!(:user_registration) { create(:registration, meeting:) }

    def attendees_path
      Decidim::EngineRouter.admin_proxy(current_component).meeting_registrations_attendees_path(meeting_id: meeting.id)
    end

    it "lists guests and users" do
      visit attendees_path

      headers = page.all("#meeting-invites thead th").map(&:text)
      expect(headers.index("Phone")).to eq(headers.index("Email") + 1)
      expect(headers.index("Type")).to eq(headers.index("Phone") + 1)
      expect(page.all("#meeting-invites tbody tr").size).to eq(2)

      within "tr[data-id='#{guest.registration.id}']" do
        expect(page).to have_content("Ana Guest")
        expect(page).to have_content("ana@example.org")
        expect(page).to have_content("+34 600 123 456")
        expect(page).to have_content("Without account")
      end

      within "tr[data-id='#{user_registration.id}']" do
        expect(page).to have_content(user_registration.user.name)
        expect(page).to have_content("With account")
      end
    end

    it "marks a guest as attendee" do
      visit attendees_path

      within "tr[data-id='#{guest.registration.id}']" do
        find("button[data-controller='dropdown']").click
        click_on "Mark as attendee"
      end

      expect(page).to have_admin_callout("Registration marked as attended successfully.")
      expect(guest.registration.reload).to be_validated
    end

    it "exports the registrations", driver: :rack_test do
      visit Decidim::EngineRouter.admin_proxy(current_component).export_meeting_registrations_path(meeting_id: meeting.id, format: "CSV")

      expect(page.response_headers["Content-Type"]).to eq("text/csv")
      expect(page.body).to include("ana@example.org")
      expect(page.body).to include(user_registration.user.email)
    end
  end
end
