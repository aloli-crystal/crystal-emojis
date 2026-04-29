require "http/client"
require "uri"

module CrystalEmojis
  # On-disk cache of emoji SVGs that aren't part of the curated
  # set embedded at compile time. Lets the consumer extend coverage
  # to the full Twemoji catalogue (~4000 SVG, ~18 MB) without
  # bloating every binary that depends on this shard.
  #
  # **Two ways to populate the cache** :
  #
  # 1. **From your own Crystal app, via the API** (no CLI needed) :
  #
  #    ```
  # require "crystal-emojis"
  #
  # # Pull every Twemoji SVG into the user-level cache.
  # CrystalEmojis::Cache.pull
  #
  # # …or override the source (private mirror, NAS, Nexus, etc.)
  # CrystalEmojis::Cache.pull(source: "https://nas.aloli.local/twemoji/svg")
  #
  # # …or write to a system-wide cache (needs root, useful for
  # # multi-user setups, e.g. a FreeBSD server provisioned via
  # # beryl).
  # CrystalEmojis::Cache.pull(system: true)
  #
  # # Inspection
  # CrystalEmojis::Cache.dir        # => "/Users/.../Library/Caches/crystal-emojis/svg"
  # CrystalEmojis::Cache.size       # => 4001 (number of cached SVGs)
  # CrystalEmojis::Cache.populated? # => true once .pull has run
  #    ```
  #
  # 2. **From the command line** :
  #
  #        $ crystal-emojis pull                                   # default source
  #        $ crystal-emojis pull --source https://example/svg/     # custom source
  #        $ crystal-emojis pull --system                          # system-wide
  #
  # **Cache location** (XDG Base Directory + macOS convention) :
  #
  # * Linux/FreeBSD : `$XDG_CACHE_HOME/crystal-emojis/svg/`
  #                   (default `~/.cache/crystal-emojis/svg/`)
  # * macOS         : `~/Library/Caches/crystal-emojis/svg/`
  # * System-wide   : `/var/cache/crystal-emojis/svg/`
  #                   (override via `CRYSTAL_EMOJIS_CACHE_DIR` env var)
  module Cache
    # Default upstream source for SVG downloads. Switch via the
    # `source:` keyword in `.pull` to point at a private mirror.
    DEFAULT_SOURCE = "https://raw.githubusercontent.com/jdecked/twemoji/main/assets/svg"

    # Returns the directory where the cache is read from / written
    # to. Honours the `CRYSTAL_EMOJIS_CACHE_DIR` env var if set,
    # otherwise computes the XDG/macOS-conventional path.
    def self.dir(system : Bool = false) : String
      if (override = ENV["CRYSTAL_EMOJIS_CACHE_DIR"]?)
        return override
      end
      if system
        "/var/cache/crystal-emojis/svg"
      elsif (xdg = ENV["XDG_CACHE_HOME"]?)
        File.join(xdg, "crystal-emojis", "svg")
      else
        case Crystal::DESCRIPTION
        when /darwin/, /macos/
          File.join(Path.home.to_s, "Library", "Caches", "crystal-emojis", "svg")
        else
          File.join(Path.home.to_s, ".cache", "crystal-emojis", "svg")
        end
      end
    end

    # Returns the cached SVG for `key` (lowercase-hex codepoint key,
    # e.g. `"1f984"` for 🦄), or `nil` when not cached.
    def self.svg(key : String) : String?
      path = File.join(dir, "#{key}.svg")
      File.exists?(path) ? File.read(path) : nil
    end

    # Counts the SVG files currently in the cache directory.
    # Returns 0 when the cache directory does not exist.
    def self.size : Int32
      Dir.exists?(dir) ? Dir.children(dir).count(&.ends_with?(".svg")) : 0
    end

    # `true` once the cache has been populated at least once
    # (any SVG present).
    def self.populated? : Bool
      size > 0
    end

    # Downloads every Twemoji SVG into the cache directory.
    #
    # The default source is the upstream Twemoji repository on
    # GitHub. Override with `source:` to fetch from a private mirror
    # (your NAS, your Nexus, an S3 bucket, …).
    #
    # The cache lookup itself is dumb : whatever `<key>.svg` files
    # are present in the cache directory will be served by `.svg`.
    # So you can also populate the cache by other means (rsync,
    # `tar -xf`, etc.) — `.pull` is just one provided way.
    #
    # Returns the number of SVGs successfully downloaded.
    def self.pull(source : String = DEFAULT_SOURCE, system : Bool = false) : Int32
      target_dir = dir(system: system)
      Dir.mkdir_p(target_dir)

      keys = list_codepoints(source)
      success = 0
      keys.each do |key|
        url = "#{source}/#{key}.svg"
        path = File.join(target_dir, "#{key}.svg")
        next if File.exists?(path) # idempotent
        if download(url, path)
          success += 1
        end
      end
      success
    end

    # Discovers the list of available codepoint keys at `source`.
    # For the upstream Twemoji repo this is done via the GitHub
    # tree API ; for custom mirrors the user can either implement
    # the same listing endpoint, or provide a `MANIFEST.txt` file
    # at `<source>/MANIFEST.txt` (one key per line).
    private def self.list_codepoints(source : String) : Array(String)
      # Try MANIFEST.txt first (works for any HTTP server).
      manifest_url = "#{source}/MANIFEST.txt"
      if (manifest = http_get(manifest_url))
        return manifest.lines.compact_map do |line|
          stripped = line.strip
          stripped.empty? || stripped.starts_with?('#') ? nil : stripped
        end
      end

      # Fallback : GitHub tree API for the upstream Twemoji repo.
      if source.starts_with?("https://raw.githubusercontent.com/jdecked/twemoji/")
        return github_twemoji_listing
      end

      raise "Cannot list codepoints at #{source} : no MANIFEST.txt and no known fallback. " \
            "Provide a MANIFEST.txt at #{manifest_url} listing one codepoint key per line."
    end

    private def self.github_twemoji_listing : Array(String)
      api_url = "https://api.github.com/repos/jdecked/twemoji/contents/assets/svg?ref=main"
      body = http_get(api_url) || raise "GitHub API request failed: #{api_url}"
      keys = [] of String
      body.scan(/"name":\s*"([0-9a-f][0-9a-f-]*)\.svg"/) do |m|
        keys << m[1]
      end
      keys
    end

    # Performs an HTTP GET and returns the body as a String, or
    # `nil` on any failure (including 404). Quiet on purpose — the
    # caller decides whether a missing resource is fatal.
    private def self.http_get(url : String) : String?
      uri = URI.parse(url)
      response = HTTP::Client.get(uri)
      return nil unless response.success?
      response.body
    rescue
      nil
    end

    # Downloads `url` to `path`. Returns true on success, false on
    # any failure. Atomic via tmp-then-rename so a partial download
    # never leaves a corrupt SVG in the cache.
    private def self.download(url : String, path : String) : Bool
      body = http_get(url)
      return false unless body
      tmp = "#{path}.tmp"
      File.write(tmp, body)
      File.rename(tmp, path)
      true
    end
  end
end
