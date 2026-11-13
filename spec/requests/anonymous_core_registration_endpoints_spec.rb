# frozen_string_literal: true

require "spec_helper"

# The core registration endpoints look registrations up by user. Without a
# session that is `user: nil`, which matches guest registrations, so they must
# stay closed to visitors.
describe "Core registration endpoints without session" do
  let(:organization) { create(:organization) }
  let(:participatory_space) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space:) }
  let(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           component:,
           available_slots: 1,
           reserved_slots: 0,
           registration_form_enabled: true,
           guest_registrations_enabled: true,
           guest_registrations_privacy_text: { en: "Privacy" })
  end
  let(:question) { create(:questionnaire_question, questionnaire: meeting.questionnaire) }
  let!(:guest) { create(:guest_registration, meeting:) }
  let!(:guest_response) { create(:response, questionnaire: meeting.questionnaire, question:, user: nil, session_token: guest.session_token) }
  let(:router) { Decidim::EngineRouter.main_proxy(component) }

  before do
    host! organization.host
    allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(true)
  end

  it "does not let a visitor leave the meeting on behalf of a guest" do
    expect { delete router.meeting_registration_path(meeting_id: meeting.id) }
      .not_to change(Decidim::Meetings::Registration, :count)

    expect(Decidim::Forms::Response.exists?(guest_response.id)).to be(true)
  end

  it "does not let a visitor join the waiting list" do
    expect { post router.join_waitlist_meeting_registration_path(meeting_id: meeting.id) }
      .not_to change(Decidim::Meetings::Registration, :count)
  end

  it "does not let a visitor respond the registration form" do
    expect do
      post router.respond_meeting_registration_path(meeting_id: meeting.id),
           params: { questionnaire: { tos_agreement: "1", responses: [{ question_id: question.id, body: "x" }] } }
    end.not_to change(Decidim::Meetings::Registration, :count)
  end

  it "does not let a visitor join through the core endpoint" do
    expect { post router.meeting_registration_path(meeting_id: meeting.id) }
      .not_to change(Decidim::Meetings::Registration, :count)
  end
end
