require "./spec_helper"

describe Emojis do
  describe ".size" do
    it "embeds the curated ~200 set" do
      # Allow some flex in either direction in case the curation
      # is later trimmed or expanded by a few entries.
      Emojis.size.should be > 150
      Emojis.size.should be < 350
    end
  end

  describe ".includes?" do
    it "covers core status & validation emojis" do
      ['✅', '❌', '⚠', '✔', '✖', '❗', '❓'].each do |char|
        Emojis.includes?(char).should be_true
      end
    end

    it "covers the colour circles family (red, green, etc.)" do
      ['🔴', '🟢', '🟡', '🔵'].each do |char|
        Emojis.includes?(char).should be_true
      end
    end

    it "covers common dev-tools emojis" do
      ['💻', '🔑', '🔒', '⚙'].each do |char|
        Emojis.includes?(char).should be_true
      end
    end

    it "rejects ASCII characters" do
      ['a', 'Z', '9', ' ', '!'].each do |char|
        Emojis.includes?(char).should be_false
      end
    end

    it "rejects Latin-1 accented letters" do
      ['é', 'à', 'ñ', 'ü'].each do |char|
        Emojis.includes?(char).should be_false
      end
    end

    it "rejects emojis intentionally NOT in this curated lite set" do
      # 🦄 unicorn — fun but not in our techie-doc subset.
      Emojis.includes?('🦄').should be_false
    end
  end

  describe ".svg" do
    it "returns a valid SVG string for a known emoji" do
      svg = Emojis.svg('✅')
      svg.should_not be_nil
      svg.not_nil!.should start_with("<svg")
      svg.not_nil!.should contain("</svg>")
    end

    it "accepts an integer codepoint as alternative input" do
      Emojis.svg(0x2705).should eq(Emojis.svg('✅'))
    end

    it "returns nil for an unknown codepoint" do
      Emojis.svg('a').should be_nil
      Emojis.svg('é').should be_nil
    end

    it "supports multi-codepoint sequences via Array(Int32)" do
      # No multi-codepoint sequence in the lite set (curation
      # focused on single-codepoint emojis), so this just verifies
      # the API doesn't crash on unknown sequences.
      Emojis.svg([0x1F468, 0x200D, 0x1F4BB]).should be_nil
    end
  end

  describe ".keys" do
    it "returns the embedded codepoint keys, sorted" do
      keys = Emojis.keys
      keys.size.should eq(Emojis.size)
      keys.should eq(keys.sort)
    end

    it "uses lowercase hex without padding (Twemoji convention)" do
      # The check codepoint U+2705 must be `2705` not `02705` or `0x2705`.
      Emojis.keys.should contain("2705")
    end
  end

  describe ".each" do
    it "iterates over every (key, svg) pair" do
      count = 0
      Emojis.each do |key, svg|
        key.should match(/\A[0-9a-f-]+\z/)
        svg.should start_with("<svg")
        count += 1
      end
      count.should eq(Emojis.size)
    end
  end
end
