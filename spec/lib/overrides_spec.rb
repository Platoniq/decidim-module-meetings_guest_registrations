# frozen_string_literal: true

require "spec_helper"

# This module overrides these files of the Decidim gems. If a checksum
# changes after a Decidim update, review the change and update the matching
# override (see the README) before updating the checksum.
checksums = [
  {
    package: "decidim-meetings",
    files: {
      "/app/models/decidim/meetings/meeting.rb" => "0f787e5cbec87a936b877ec10d23f725",
      "/app/models/decidim/meetings/registration.rb" => "6c0b6535377adfe78dc20d735da9a976",
      "/app/forms/decidim/meetings/admin/meeting_registrations_form.rb" => "327c1305f3e0151a04cc50eb9deb7aab",
      "/app/commands/decidim/meetings/admin/update_registrations.rb" => "1442ac293c391d5d82321a1050100716",
      "/app/commands/decidim/meetings/admin/mark_as_attendee.rb" => "4989a2060e78e3f63a81c795fed946a2",
      "/app/commands/decidim/meetings/admin/validate_registration_code.rb" => "fea22d87751fbd09dbc9ef8383eef26e",
      "/app/commands/decidim/meetings/admin/update_meeting.rb" => "178f4dd2beab35c644214f5695b5925e",
      "/app/commands/decidim/meetings/admin/unpublish_meeting.rb" => "2b183892154fd5102c032c2157a5e69e",
      "/app/commands/decidim/meetings/update_meeting.rb" => "01e1c94369171c335e4eca8176fecc3f",
      "/app/commands/decidim/meetings/withdraw_meeting.rb" => "e5fdf31f169dc6e4cb0505348f49fb85",
      "/app/commands/decidim/meetings/leave_meeting.rb" => "f64b7e73c447fca1b19ba2ac3ff7d612",
      "/app/commands/decidim/meetings/admin/copy_meeting.rb" => "f3fafb4cc66019bb9b8c3d008636b039",
      "/app/jobs/decidim/meetings/promote_from_waitlist_job.rb" => "e282f72cf4fd40805ce6778cf8325e5f",
      "/app/jobs/decidim/meetings/upcoming_meeting_notification_job.rb" => "900cb01a7c30d6176b73c9aa2f9b35b0",
      "/app/presenters/decidim/meetings/registration_presenter.rb" => "afdf5f16e2c81d0d44246cffa23ca824",
      "/app/serializers/decidim/meetings/registration_serializer.rb" => "7aad7239fff78f1a6f9c78d054a2a9ef",
      "/app/permissions/decidim/meetings/meeting_permissions.rb" => "fb26a57356d1070b4eeabdc0dfd12e20",
      "/app/controllers/decidim/meetings/meetings_controller.rb" => "7d4e23b02b5ef49eef0a4ba45f7b1bc9",
      "/app/cells/decidim/meetings/join_meeting_button_cell.rb" => "6dcb71229b789b7ceef2736c2322fc7c",
      "/app/cells/decidim/meetings/join_meeting_button/show.erb" => "dba7e8b77e04abfe953e0a312b9106f1",
      "/app/cells/decidim/meetings/join_meeting_button/waitlist_button.erb" => "3614f114f8a7a681b25f0f53ca466c30",
      "/app/views/decidim/meetings/admin/registrations/_form.html.erb" => "4b149ebad06cfe37a7d25204011dd75d",
      "/app/views/decidim/meetings/admin/registrations_attendees/index.html.erb" => "0b242029f7ec2d4791c4ff4d238d88cd"
    }
  },
  {
    package: "decidim-core",
    files: {
      "/app/queries/decidim/stats_participants_count.rb" => "a9e48f00a68e0a62d405c9180b4f463f"
    }
  }
]

describe "Overridden files", type: :view do
  checksums.each do |item|
    item[:files].each do |file, signature|
      it "#{item[:package]}#{file} matches checksum" do
        gem_dir = Gem::Specification.find_by_name(item[:package]).gem_dir
        expect(md5("#{gem_dir}#{file}")).to eq(signature)
      end
    end
  end

  private

  def md5(file)
    Digest::MD5.hexdigest(File.read(file))
  end
end
