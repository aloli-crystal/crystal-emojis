require "./emojis/cache"

# Embeds ~200 commonly-used emoji as SVG assets from Twemoji
# (https://github.com/jdecked/twemoji), with an opt-in on-disk
# cache for the rest of the catalogue.
#
# All curated SVGs are read and inlined at compile time (via the
# `read_file` macro), so consumers don't need to ship the
# `data/` directory alongside their compiled binaries.
#
# **Lookup chain** :
#
# 1. The 208 curated emojis are baked into the binary and served
#    from RAM.
# 2. Anything else is looked up in the on-disk cache (cf.
#    `Emojis::Cache`). The cache is empty by default —
#    populate it via `Emojis::Cache.pull` (API) or
#    `emojis pull` (CLI).
# 3. If still not found, returns `nil` and the caller decides
#    (typically substitutes with `?` or text fallback).
#
# **Why two layers** : the curated set covers the 90 % case of
# technical documentation (status, colours, dev tools…) at near-zero
# cost (~840 KB embedded). The cache covers the long tail without
# inflating every dependent binary by 18 MB.
module Emojis
  # Version of this Crystal shard.
  # Lue au compile-time depuis `shard.yml` via le macro `read_file`.
  # Cf. note mémoire `feedback_shard_version_macro.md` (mémoire ALOLI).
  VERSION = {{
              (read_file("#{__DIR__}/../shard.yml")
                .lines
                .find(&.starts_with?("version:")) || "version: 0.0.0")
                .gsub(/^version:\s*/, "")
                .chomp
            }}

  # Version of Twemoji whose curated assets are embedded.
  TWEMOJI_VERSION = "main"

  # Compile-time hash of `codepoint_key => svg_content` for the
  # curated set. Codepoint keys are lowercase hex, multi-codepoint
  # sequences joined with `-` (Twemoji file naming convention).
  # Built from `data/svg/MANIFEST.txt`.
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
  #
  # Looks up first in the embedded curated set, then in the
  # on-disk cache. Returns `nil` when neither has the emoji —
  # callers should fall back to text.
  #
  # ```
  # Emojis.svg('✅') # => "<svg ...>"  (curated)
  # Emojis.svg('🦄') # => "<svg ...>" if cache populated, else nil
  # Emojis.svg('é') # => nil          (not an emoji)
  # ```
  def self.svg(char : Char) : String?
    svg(char.ord)
  end

  # :ditto:
  def self.svg(codepoint : Int32) : String?
    key = codepoint_key(codepoint)
    EMOJIS[key]? || Cache.svg(key)
  end

  # Returns the SVG for a multi-codepoint emoji sequence (e.g. an
  # emoji modified by a skin-tone or zero-width-joiner). Pass an
  # array of codepoints in source order.
  #
  # The curated set focuses on single-codepoint emojis ; sequences
  # are typically only available once the cache has been populated.
  #
  # ```
  # # 👨‍💻 = MAN (1F468) + ZWJ (200D) + LAPTOP (1F4BB)
  # Emojis.svg([0x1F468, 0x200D, 0x1F4BB])
  # ```
  def self.svg(codepoints : Array(Int32)) : String?
    key = codepoints.map(&.to_s(16)).join('-')
    EMOJIS[key]? || Cache.svg(key)
  end

  # Returns `true` when **either** the curated set **or** the cache
  # has an SVG for the given codepoint. Cheaper than `svg(...)` for
  # the curated branch (no string copy), but the cache branch still
  # has to stat the file.
  def self.includes?(char : Char) : Bool
    includes?(char.ord)
  end

  # :ditto:
  def self.includes?(codepoint : Int32) : Bool
    key = codepoint_key(codepoint)
    EMOJIS.has_key?(key) || !Cache.svg(key).nil?
  end

  # Iterates over every (key, svg) pair in the **embedded** curated
  # set only — the cache is intentionally NOT walked, since it can
  # grow to thousands of entries and most callers using `each` want
  # to enumerate the small fast set, not the disk one.
  def self.each(& : String, String ->) : Nil
    EMOJIS.each { |k, v| yield k, v }
  end

  # Returns the number of emojis in the **embedded** curated set
  # (does NOT count cached SVGs ; see `Cache.size` for that).
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
