#!/usr/bin/env bash
# Envoie un message au canal de l'équipe (webhook entrant). L'adresse est un
# secret (REPOGARDE_WEBHOOK), jamais écrite dans un fichier du dépôt.
#   ci/notifier.sh <clé de message> [arguments]   (catalogue de traduction)
# Format adapté à la plateforme d'après l'adresse : Slack, Discord, Microsoft
# Teams (Workflows / connecteur), sinon {"text"} (Mattermost, Rocket.Chat…).
# Sans adresse : rien n'est envoyé, sans erreur. Un échec d'envoi n'interrompt
# jamais une release : il est seulement signalé.
set -euo pipefail

REPOGARDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$REPOGARDE_DIR/hooks/lib/common.sh"

url="${REPOGARDE_WEBHOOK:-}"
[ -n "$url" ] || exit 0
_tr "$@"
text="$_T"

# Chaîne JSON échappée (guillemets, barres obliques inverses, retours à la ligne)
json() {
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    printf '"%s"' "$s"
}

case "$url" in
    *discord.com/* | *discordapp.com/*) payload="{\"content\": $(json "$text")}" ;;
    *webhook.office.com/* | *logic.azure.com/* | *powerplatform.com/* | *powerautomate.com/*)
        payload="{\"type\": \"message\", \"attachments\": [{\"contentType\": \"application/vnd.microsoft.card.adaptive\",
  \"content\": {\"type\": \"AdaptiveCard\", \"version\": \"1.4\", \"body\": [{\"type\": \"TextBlock\", \"wrap\": true, \"text\": $(json "$text")}]}}]}"
        ;;
    *) payload="{\"text\": $(json "$text")}" ;; # Slack, Mattermost, Rocket.Chat, générique
esac

if curl -fsS --max-time 15 -H "Content-Type: application/json" -d "$payload" "$url" >/dev/null 2>&1; then
    ok_t ci.notify.sent
else
    attention_t ci.notify.failed
fi
