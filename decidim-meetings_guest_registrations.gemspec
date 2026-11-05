# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/meetings_guest_registrations/version"

Gem::Specification.new do |s|
  s.version = Decidim::MeetingsGuestRegistrations.version
  s.authors = ["Fran Bolívar"]
  s.email = ["francisco.bolivar@nazaries.com"]
  s.license = "AGPL-3.0-or-later"
  s.homepage = "https://github.com/AjuntamentdeBarcelona/decidim-module-meetings_guest_registrations"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/AjuntamentdeBarcelona/decidim-module-meetings_guest_registrations/issues",
    "source_code_uri" => "https://github.com/AjuntamentdeBarcelona/decidim-module-meetings_guest_registrations",
    "rubygems_mfa_required" => "true"
  }
  s.required_ruby_version = "~> 3.4"

  s.name = "decidim-meetings_guest_registrations"
  s.summary = "Registrations to Decidim meetings without an account"
  s.description = "Lets people without an account register to the Decidim meetings that allow it, giving their name, email and phone."

  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w(app/ config/ db/ lib/ LICENSE-AGPLv3.txt Rakefile README.md))
    end
  end

  s.add_dependency "decidim-core", Decidim::MeetingsGuestRegistrations::COMPAT_DECIDIM_VERSION
  s.add_dependency "decidim-forms", Decidim::MeetingsGuestRegistrations::COMPAT_DECIDIM_VERSION
  s.add_dependency "decidim-meetings", Decidim::MeetingsGuestRegistrations::COMPAT_DECIDIM_VERSION
  s.add_dependency "deface", ">= 1.5"
end
