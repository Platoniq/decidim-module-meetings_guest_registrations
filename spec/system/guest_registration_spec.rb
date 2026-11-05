# frozen_string_literal: true

require "spec_helper"

describe "Guest registration" do
  include_context "with a component"
  let(:manifest_name) { "meetings" }

  let(:available_slots) { 10 }
  let(:registration_form_enabled) { false }
  let!(:meeting) do
    create(:meeting, :published,
           component:,
           author: organization,
           registrations_enabled: true,
           registration_form_enabled:,
           available_slots:,
           reserved_slots: 0,
           registration_terms: { en: "The registration terms" },
           guest_registrations_enabled: true,
           guest_registrations_privacy_text: { en: "The data protection text" })
  end

  def visit_meeting
    visit resource_locator(meeting).path
  end

  def fill_in_guest_form(email: "ana@example.org")
    fill_in "Name and surname", with: "Ana Guest"
    fill_in "Email", with: email
    fill_in "Phone", with: "+34 600 123 456"
    check "I have read and accept the data protection information"
    check "I accept the registration terms"
  end

  before do
    stub_geocoding_coordinates([meeting.latitude, meeting.longitude])
  end

  it "registers, receives the e-mail and cancels with the link" do
    visit_meeting
    click_on "Register"

    expect(page).to have_content("Register to the meeting")
    expect(page).to have_content("The data protection text")
    expect(page).to have_content("The registration terms")

    fill_in_guest_form
    perform_enqueued_jobs do
      click_on "Register"
      expect(page).to have_content("Your registration has been confirmed")
    end

    expect(meeting.registrations.guests.count).to eq(1)

    email = last_email
    expect(email.to).to eq(["ana@example.org"])
    cancel_link = email.html_part ? email.html_part.body.decoded[/href="([^"]+cancel[^"]+)"/, 1] : email.body.decoded[/href="([^"]+cancel[^"]+)"/, 1]
    expect(cancel_link).to be_present

    visit CGI.unescapeHTML(cancel_link).sub(%r{\Ahttps?://[^/]+}, "")
    expect(page).to have_content("Do you want to cancel your registration")

    perform_enqueued_jobs do
      click_on "Cancel my registration"
      expect(page).to have_content("Your registration has been cancelled")
    end

    expect(meeting.registrations.count).to eq(0)
    expect(last_email.subject).to include("Registration cancelled")
  end

  it "shows the form errors" do
    visit Decidim::EngineRouter.main_proxy(component).new_meeting_guest_registration_path(meeting_id: meeting.id)

    fill_in_guest_form(email: "wrong")
    click_on "Register"

    expect(page).to have_content("There was a problem with your registration")
    expect(meeting.registrations.count).to eq(0)
  end

  it "does not allow the same email twice" do
    create(:guest_registration, meeting:, email: "ana@example.org")

    visit Decidim::EngineRouter.main_proxy(component).new_meeting_guest_registration_path(meeting_id: meeting.id)
    fill_in_guest_form
    click_on "Register"

    expect(page).to have_content("is already registered to this meeting")
  end

  it "does not cancel once the meeting has started" do
    guest = create(:guest_registration, meeting:)
    meeting.update!(start_time: 1.hour.ago, end_time: 1.hour.from_now)

    visit Decidim::EngineRouter.main_proxy(component).cancel_meeting_guest_registration_path(meeting_id: meeting.id, token: guest.cancellation_token)

    expect(page).to have_content("This registration can no longer be cancelled")
    expect(page).to have_current_path(resource_locator(meeting).path)
    expect(meeting.registrations.count).to eq(1)
  end

  it "goes back to the meeting, not to the login, when guests are not allowed" do
    meeting.update!(guest_registrations_enabled: false)

    visit Decidim::EngineRouter.main_proxy(component).new_meeting_guest_registration_path(meeting_id: meeting.id)

    expect(page).to have_content("Registrations without an account are not available for this meeting")
    expect(page).to have_current_path(resource_locator(meeting).path)
  end

  it "rejects an invalid cancellation token" do
    visit Decidim::EngineRouter.main_proxy(component).cancel_meeting_guest_registration_path(meeting_id: meeting.id, token: "invalid")

    expect(page).to have_content("This cancellation link is not valid")
  end

  context "when the meeting has a registration form" do
    let(:registration_form_enabled) { true }
    let!(:question) { create(:questionnaire_question, questionnaire: meeting.questionnaire, question_type: :short_response, body: { en: "Why do you come?" }) }

    it "responds the questions in the same page" do
      visit Decidim::EngineRouter.main_proxy(component).new_meeting_guest_registration_path(meeting_id: meeting.id)

      expect(page).to have_content("Why do you come?")
      fill_in question.body["en"], with: "To learn"
      fill_in_guest_form
      click_on "Register"

      expect(page).to have_content("Your registration has been confirmed")
      expect(meeting.questionnaire.responses.last.body).to eq("To learn")
    end
  end

  context "when there are no slots left" do
    let(:available_slots) { 1 }

    before do
      create(:guest_registration, meeting:)
      allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(true)
    end

    it "joins the waiting list" do
      visit_meeting
      click_on "Join waitlist"

      expect(page).to have_content("There are no places left")
      fill_in_guest_form
      click_on "Join the waiting list"

      expect(page).to have_content("You have been added to the waiting list")
      expect(meeting.registrations.waiting_list.count).to eq(1)
    end
  end

  context "when the user is signed in" do
    let(:user) { create(:user, :confirmed, organization:) }

    before { login_as user, scope: :user }

    it "keeps the regular flow" do
      visit_meeting
      click_on "Register"

      within "#meeting-registration-confirm-#{meeting.id}" do
        click_on "Confirm"
      end

      expect(page).to have_content("You have joined the meeting successfully")
      expect(meeting.registrations.last.user).to eq(user)
    end

    it "is redirected from the guest form" do
      visit Decidim::EngineRouter.main_proxy(component).new_meeting_guest_registration_path(meeting_id: meeting.id)

      expect(page).to have_current_path(resource_locator(meeting).path)
    end
  end

  context "when guest registrations are disabled" do
    before { meeting.update!(guest_registrations_enabled: false) }

    it "opens the login modal" do
      visit_meeting
      click_on "Register"

      expect(page).to have_css("#loginModal", visible: :visible)
    end
  end

  context "when there are guests registered" do
    let!(:guest) { create(:guest_registration, meeting:, name: "Secret Guest") }

    before { component.update!(settings: { registration_code_enabled: true }) }

    it "does not show them in the meeting page, nor their code to visitors" do
      visit_meeting

      expect(page).to have_no_content("Secret Guest")
      expect(page).to have_no_content(guest.registration.code)
    end
  end
end
