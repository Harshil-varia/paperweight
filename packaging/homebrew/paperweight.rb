cask "paperweight" do
  version "0.1.0"
  sha256 "f628f07db54769a8911516dac3fc9bf72fcdac232844e886df9df15038bcdcec"

  url "https://github.com/Harshil-varia/paperweight/releases/download/v#{version}/Paperweight.dmg"
  name "Paperweight"
  desc "Menu-bar paper-texture screen overlay that reduces glare"
  homepage "https://github.com/Harshil-varia/paperweight"

  depends_on macos: ">= :ventura"

  app "Paperweight.app"

  # Paperweight is an unsigned, ad-hoc internal build (no paid Apple Developer
  # account). Strip the download quarantine so it launches without a Gatekeeper
  # "unidentified developer" prompt.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Paperweight.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.humanlayer.paperweight.plist",
    "~/Library/Caches/com.humanlayer.paperweight",
  ]
end
