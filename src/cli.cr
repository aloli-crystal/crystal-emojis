require "option_parser"
require "./emojis"

# emojis CLI — manages the on-disk emoji SVG cache.
#
# Usage examples (shell):
#   $ emojis pull                                # default Twemoji upstream
#   $ emojis pull --source https://your.mirror/  # private mirror
#   $ emojis pull --system                       # system-wide cache
#   $ emojis info                                # cache location + size
#   $ emojis purge                               # delete cached SVGs

source = Emojis::Cache::DEFAULT_SOURCE
system_cache = false

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : emojis SOUS-COMMANDE [options]

    Sous-commandes :
      pull          Télécharge le set Twemoji complet dans le cache local
      info          Affiche l'emplacement et la taille du cache
      purge         Vide le cache local

    Options de `pull` :
    BANNER

  p.on("-s URL", "--source URL", "URL source pour le téléchargement (défaut : Twemoji upstream)") { |v| source = v }
  p.on("--system", "Écrit dans le cache système (/var/cache/emojis)") { system_cache = true }

  p.separator ""
  p.separator "Aide :"
  p.on("-v", "--version", "Afficher la version") do
    puts "emojis #{Emojis::VERSION}"
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
when "help", "-h", "--help"
  # UX standard `<cli> help [<sub>]` — cf. note mémoire ALOLI
  # `feedback_cli_help_subcommand.md`. Sans argument c'est l'aide
  # globale. Avec argument on filtre sur la sous-commande demandée
  # pour pointer vite à la bonne section.
  sub = positional[1]?
  if sub.nil? || sub.empty?
    puts parser
    exit 0
  end
  valid_subs = %w(pull info purge)
  unless valid_subs.includes?(sub.downcase)
    STDERR.puts "Aide indisponible pour « #{sub} » (sous-commandes : #{valid_subs.join(", ")})."
    STDERR.puts "Utilisez `emojis help` pour l'aide globale."
    exit 1
  end
  full = parser.to_s
  puts full
  puts ""
  puts "─── Focus : #{sub} ───"
  full.lines.each_with_index do |line, i|
    if line.includes?("  #{sub}  ") || line.lstrip.starts_with?("#{sub} ")
      full.lines[i, 6].each { |l| puts l.rstrip }
      break
    end
  end
  exit 0
when "pull"
  target = Emojis::Cache.dir(system: system_cache)
  puts "Téléchargement vers : #{target}"
  puts "Source              : #{source}"
  puts "Patientez (≈ 4000 SVG, ~18 Mo)..."
  count = Emojis::Cache.pull(source: source, system: system_cache)
  puts "Téléchargé : #{count} nouveau(x) SVG (cache total : #{Emojis::Cache.size})"
when "info"
  puts "Emplacement : #{Emojis::Cache.dir(system: system_cache)}"
  puts "Taille      : #{Emojis::Cache.size} SVG"
  puts "Embarqués   : #{Emojis.size} (curated set)"
when "purge"
  dir = Emojis::Cache.dir(system: system_cache)
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
