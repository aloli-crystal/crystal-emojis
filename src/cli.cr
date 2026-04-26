require "option_parser"
require "./crystal_emojis"

# crystal-emojis CLI — manages the on-disk emoji SVG cache.
#
# Usage examples (shell):
#   $ crystal-emojis pull                                # default Twemoji upstream
#   $ crystal-emojis pull --source https://your.mirror/  # private mirror
#   $ crystal-emojis pull --system                       # system-wide cache
#   $ crystal-emojis info                                # cache location + size
#   $ crystal-emojis purge                               # delete cached SVGs

source = CrystalEmojis::Cache::DEFAULT_SOURCE
system_cache = false

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : crystal-emojis SOUS-COMMANDE [options]

    Sous-commandes :
      pull          Télécharge le set Twemoji complet dans le cache local
      info          Affiche l'emplacement et la taille du cache
      purge         Vide le cache local

    Options de `pull` :
    BANNER

  p.on("-s URL", "--source URL", "URL source pour le téléchargement (défaut : Twemoji upstream)") { |v| source = v }
  p.on("--system", "Écrit dans le cache système (/var/cache/crystal-emojis)") { system_cache = true }

  p.separator ""
  p.separator "Aide :"
  p.on("-v", "--version", "Afficher la version") do
    puts "crystal-emojis #{CrystalEmojis::VERSION}"
    exit 0
  end
  p.on("-h", "--help", "Afficher l'aide") do
    puts p
    exit 0
  end

  p.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts p
    exit 1
  end
end

positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

if positional.empty?
  STDERR.puts "Erreur : aucune sous-commande spécifiée"
  STDERR.puts parser
  exit 1
end

case positional.first
when "pull"
  target = CrystalEmojis::Cache.dir(system: system_cache)
  puts "Téléchargement vers : #{target}"
  puts "Source              : #{source}"
  puts "Patientez (≈ 4000 SVG, ~18 Mo)..."
  count = CrystalEmojis::Cache.pull(source: source, system: system_cache)
  puts "Téléchargé : #{count} nouveau(x) SVG (cache total : #{CrystalEmojis::Cache.size})"
when "info"
  puts "Emplacement : #{CrystalEmojis::Cache.dir(system: system_cache)}"
  puts "Taille      : #{CrystalEmojis::Cache.size} SVG"
  puts "Embarqués   : #{CrystalEmojis.size} (curated set)"
when "purge"
  dir = CrystalEmojis::Cache.dir(system: system_cache)
  if Dir.exists?(dir)
    Dir.children(dir).each do |entry|
      File.delete(File.join(dir, entry)) if entry.ends_with?(".svg")
    end
    puts "Cache vidé : #{dir}"
  else
    puts "Aucun cache à vider en #{dir}"
  end
else
  STDERR.puts "Erreur : sous-commande inconnue « #{positional.first} »"
  STDERR.puts parser
  exit 1
end
