# Embeds ~200 commonly-used emoji as SVG assets from Twemoji
# (https://github.com/jdecked/twemoji, MIT). Exposes a minimal
# Crystal API: lookup by codepoint or by `Char`, enumeration,
# and detection helpers.
#
# All SVGs are read and inlined at compile time (via the
# `read_file` macro), so consumers don't need to ship the
# `data/` directory alongside their compiled binaries.
#
# For the full ~3700-emoji set, use the sibling shard
# `crystal-emojis-full` instead — same API, larger binary
# footprint (~7-12 MB embedded vs ~840 KB here).
module CrystalEmojis
  # Version of this Crystal shard.
  VERSION = "0.1.0"

  # Version of Twemoji whose assets are embedded.
  TWEMOJI_VERSION = "main"

  # Compile-time hash of `codepoint_key => svg_content`. Codepoint
  # keys are lowercase hex, multi-codepoint sequences joined with
  # `-` (Twemoji file naming convention). Built from the curated
  # `data/svg/MANIFEST.txt` list.
  #
  # We use a local helper file (`MANIFEST.txt`) rather than walking
  # the directory at compile time because `read_file` macros work
  # on a known set of paths but Crystal's compile-time
  # introspection cannot enumerate a directory generically.
  EMOJIS = begin
    map = {} of String => String
    {% for line in read_file(__DIR__ + "/../data/svg/MANIFEST.txt").split("\n") %}
      {% key = line.split("#").first.strip %}
      {% if key.size > 0 %}
        map[{{ key }}] = {{ read_file(__DIR__ + "/../data/svg/" + key + ".svg") }}
      {% end %}
    {% end %}
    map
  end

  # Returns the raw SVG content for a single-codepoint emoji.
  # Pass a `Char` (most natural) or an `Int32` codepoint.
  # Returns `nil` when the codepoint is not in this curated set —
  # callers should fall back to text or to the larger
  # `crystal-emojis-full` set.
  #
  # ```
  # CrystalEmojis.svg('✅')    # => "<svg ...>"
  # CrystalEmojis.svg(0x2705) # => "<svg ...>"  (same)
  # CrystalEmojis.svg('é')    # => nil          (not an emoji)
  # ```
  def self.svg(char : Char) : String?
    svg(char.ord)
  end

  # :ditto:
  def self.svg(codepoint : Int32) : String?
    EMOJIS[codepoint_key(codepoint)]?
  end

  # Returns the SVG for a multi-codepoint emoji sequence (e.g. an
  # emoji modified by a skin-tone or zero-width-joiner). Pass an
  # array of codepoints in source order.
  #
  # ```
  # # 👨‍💻 = MAN (1F468) + ZWJ (200D) + LAPTOP (1F4BB)
  # CrystalEmojis.svg([0x1F468, 0x200D, 0x1F4BB])
  # ```
  def self.svg(codepoints : Array(Int32)) : String?
    EMOJIS[codepoints.map(&.to_s(16)).join('-')]?
  end

  # Returns `true` when this curated set covers the given codepoint.
  # Cheaper than `svg(...)` because it returns `nil`/non-nil without
  # copying the SVG string.
  def self.includes?(char : Char) : Bool
    includes?(char.ord)
  end

  # :ditto:
  def self.includes?(codepoint : Int32) : Bool
    EMOJIS.has_key?(codepoint_key(codepoint))
  end

  # Iterates over every (key, svg) pair in the embedded set.
  # `key` is the lowercase-hex Twemoji-style identifier
  # (`"2705"` for ✅, `"1f468-200d-1f4bb"` for 👨‍💻).
  def self.each(& : String, String ->) : Nil
    EMOJIS.each { |k, v| yield k, v }
  end

  # Returns the number of emojis embedded in this set.
  def self.size : Int32
    EMOJIS.size
  end

  # Returns every embedded codepoint key (sorted alphabetically).
  # Useful for `--list-emojis` style commands or for documentation.
  def self.keys : Array(String)
    EMOJIS.keys.to_a.sort
  end

  # Lowercase-hex representation of a single-codepoint key (no
  # padding — Twemoji uses `2705` not `02705`).
  private def self.codepoint_key(codepoint : Int32) : String
    codepoint.to_s(16)
  end
end
