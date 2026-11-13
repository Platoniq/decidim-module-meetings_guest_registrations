# frozen_string_literal: true

# Loaded by decidim-dev (base_spec_helper) when SIMPLECOV is set, as Decidim does.
if ENV["SIMPLECOV"]
  SimpleCov.start do
    root __dir__

    # Track every file, also the ones no spec loads.
    track_files "{app,lib}/**/*.rb"

    add_filter "/config/"
    add_filter "/db/"
    add_filter "/node_modules/"
    add_filter "/spec/"
    add_filter "/vendor/"
    add_filter "/lib/decidim/meetings_guest_registrations/test/"
    add_filter "/lib/decidim/meetings_guest_registrations/engine.rb"
    # Loaded by the gemspec before SimpleCov starts.
    add_filter "/lib/decidim/meetings_guest_registrations/version.rb"
  end

  SimpleCov.merge_timeout 1800

  # Coveralls reads the Cobertura report (coverage/coverage.xml).
  if ENV["CI"]
    require "simplecov-cobertura"
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end
end
