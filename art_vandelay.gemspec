require_relative "lib/art_vandelay/version"

Gem::Specification.new do |spec|
  spec.name = "art_vandelay"
  spec.version = ArtVandelay::VERSION
  spec.authors = ["Steve Polito"]
  spec.email = ["stevepolito@hey.com"]
  spec.homepage = "https://github.com/thoughtbot/art_vandelay"
  spec.summary = "Art Vandelay is an importer/exporter for Rails"
  spec.description = "Art Vandelay is an importer/exporter for Rails"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/thoughtbot/art_vandelay"
  spec.metadata["changelog_uri"] = "https://github.com/thoughtbot/art_vandelay/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails"
end
