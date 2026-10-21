# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/meetings_guest_registrations/version"

Gem::Specification.new do |s|
  s.version = Decidim::MeetingsGuestRegistrations.version
  s.authors = ["Fran Bolívar"]
  s.email = ["francisco.bolivar@nazaries.com"]
  s.license = "AGPL-3.0-or-later"
  s.homepage = "https://decidim.org"
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/decidim/decidim/issues",
    "documentation_uri" => "https://docs.decidim.org/",
    "funding_uri" => "https://opencollective.com/decidim",
    "homepage_uri" => "https://decidim.org",
    "source_code_uri" => "https://github.com/decidim/decidim"
  }
  s.required_ruby_version = "~> 3.4"

  s.name = "decidim-meetings_guest_registrations"
  s.summary = "A decidim meetings_guest_registrations module"
  s.description = "."

  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w(app/ config/ db/ lib/ LICENSE-AGPLv3.txt Rakefile README.md))
    end
  end

  s.add_dependency "decidim-core", Decidim::MeetingsGuestRegistrations.version
end
