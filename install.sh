#!/bin/bash
# =============================================================================
#  NMA EDITOR — installation sur un Mac
#
#  Script PUBLIC, sans secret : il demande le jeton d'accès au dépôt privé.
#  Tout s'installe dans le dossier personnel, sans mot de passe administrateur.
#  Reprend là où ça s'est arrêté si on le relance. « install.sh --verifier »
#  vérifie une installation sans rien modifier.
#
#  Même socle que Derush Studio et NMA Auditor (Node, ffmpeg, environnement
#  Python, modèle Whisper) : si l'un d'eux est déjà installé, ces étapes sont
#  instantanées. En plus : Node complet (npx, pour HyperFrames), le navigateur
#  de rendu de HyperFrames, Claude Code (chaque salarié se connecte avec
#  son propre abonnement), et le détourage RVM (PyTorch + RobustVideoMatting,
#  en local, gratuit : la règle de Tom pour tout détourage).
# =============================================================================
set -u
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/usr/bin/true

DEPOT="CONTINUDESCROLL/nma-editor"
BIN="$HOME/.local/bin"
NODE_DIR="$HOME/.local/opt/node22"
VENV="$HOME/.local/opt/whisper-env"
NODE_V="v22.23.1"
MARQUEUR="$HOME/.nma-editor/emplacement"
ETAPES=9
RVM_DIR="$HOME/.rvm-tool"

JETON=""; export JETON
armer_git() { JETON="$1"; ASKPASS=$(mktemp); chmod 700 "$ASKPASS"
  # nom d'utilisateur = le propriétaire du dépôt (ce que GitHub attend avec un jeton personnel) ; mot de passe = le jeton
  printf '#!/bin/sh\ncase "$1" in *sername*) echo %s ;; *) printf "%%s" "$JETON" ;; esac\n' "${DEPOT%%/*}" > "$ASKPASS"
  export GIT_ASKPASS="$ASKPASS"; }
ranger_jeton() {                      # $1 = dossier de l'application : pour les mises à jour depuis l'app
  [ -d "$1/.git" ] || return 0
  git -C "$1" remote set-url origin "https://github.com/$DEPOT.git" 2>/dev/null
  printf 'https://%s:%s@github.com\n' "${DEPOT%%/*}" "$JETON" > "$1/.git/.identifiants"
  chmod 600 "$1/.git/.identifiants"
  # le trousseau macOS peut contenir un autre compte GitHub (celui du salarié) : on l'écarte pour ce dépôt, seul le jeton compte
  git -C "$1" config credential.helper ""
  # chemin entre guillemets : le dossier s'appelle « NMA Editor » (espace) et git passe cette commande par le shell
  git -C "$1" config --add credential.helper "store --file=\"$1/.git/.identifiants\""
  chmod 600 "$1/.git/config" 2>/dev/null; }

as_txt() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
rouge() { printf "\033[31m%s\033[0m\n" "$*"; }
vert()  { printf "\033[32m  ✓ %s\033[0m\n" "$*"; }
gris()  { printf "\033[90m    %s\033[0m\n" "$*"; }
etape() { printf "\n\033[1m[%s/%s] %s\033[0m\n" "$1" "$ETAPES" "$2"; }
fatal() { echo ""; rouge "  ✗ $1"; [ $# -gt 1 ] && gris "$2"
          osascript -e "display alert \"Installation interrompue\" message \"$(as_txt "$1")\"" >/dev/null 2>&1
          echo ""; exit 1; }

# Claude Code peut être à plusieurs endroits selon la façon dont il a été installé.
trouver_claude() { for c in "$BIN/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$(command -v claude 2>/dev/null)"; do
  [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }; done; return 1; }
claude_connecte() { security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1 || [ -s "$HOME/.claude/.credentials.json" ]; }

# ----------------------------------------------------------------------------- vérifier
PROBLEMES=0; SOUCIS=""
verifier() {
  local A="$1" M=0 f C
  PROBLEMES=0; SOUCIS=""
  souci() { PROBLEMES=$((PROBLEMES+1)); SOUCIS="$SOUCIS
  · $1"; rouge "  ✗ $1"; }
  if [ -x "$NODE_DIR/bin/node" ] && [ -x "$NODE_DIR/bin/npx" ]; then vert "Node $("$NODE_DIR/bin/node" --version) avec npx"; else souci "Node complet (avec npx) absent"; fi
  for o in ffmpeg ffprobe; do if [ -s "$BIN/$o" ] && "$BIN/$o" -version >/dev/null 2>&1; then vert "$o"; else souci "$o absent"; fi; done
  if [ -s "$BIN/yt-dlp" ] && "$BIN/yt-dlp" --version >/dev/null 2>&1; then vert "yt-dlp $("$BIN/yt-dlp" --version)"; else souci "yt-dlp absent"; fi
  if [ -s "$VENV/bin/python" ] && "$VENV/bin/python" -c 'import faster_whisper' >/dev/null 2>&1; then vert "moteur de transcription"; else souci "moteur de transcription absent"; fi
  for f in "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-medium"/snapshots/*/model.bin; do [ -f "$f" ] && M=$(wc -c < "$f" 2>/dev/null || echo 0); done
  if [ "$M" -gt 1000000000 ]; then vert "modèle de transcription"; else souci "modèle de transcription incomplet"; fi
  if C=$(trouver_claude); then vert "Claude Code ($("$C" --version 2>/dev/null | head -1))"; else souci "Claude Code absent"; fi
  if claude_connecte; then vert "Claude Code connecté à un compte"; else souci "Claude Code pas encore connecté : ouvre le Terminal, tape « claude » et connecte-toi"; fi
  [ -n "$(ls -d "$HOME/.cache/hyperframes/chrome"/* 2>/dev/null)" ] && vert "navigateur de rendu HyperFrames" || souci "navigateur de rendu HyperFrames absent"
  if /usr/bin/python3 -E -c 'import torch, torchvision, numpy' >/dev/null 2>&1; then vert "PyTorch (détourage)"; else souci "PyTorch absent : le détourage RVM ne marchera pas"; fi
  [ -f "$RVM_DIR/repo/model/__init__.py" ] && [ "$(wc -c < "$RVM_DIR/weights/rvm_resnet50.pth" 2>/dev/null || echo 0)" -gt 100000000 ] && vert "détourage RVM" || souci "détourage RVM absent"
  [ -f "$A/server.mjs" ] && [ -f "$A/public/index.html" ] && [ -d "$A/skills" ] && vert "fichiers de l'application" || souci "fichiers de l'application manquants"
  [ -d "$A/.git" ] && vert "mises à jour possibles depuis l'application" || souci "pas de dépôt git : les mises à jour en un clic ne marcheront pas"
  [ -s "$A/Lancer NMA Editor.command" ] && vert "lanceur" || souci "lanceur absent"
  return 0
}
if [ "${1:-}" = "--verifier" ]; then
  CIBLE="$(cat "$MARQUEUR" 2>/dev/null)"; [ -n "$CIBLE" ] && [ -f "$CIBLE/server.mjs" ] || CIBLE="$HOME/NMA Editor"
  echo ""; printf "\033[1m  VÉRIFICATION DE L'INSTALLATION\033[0m\n"; gris "$CIBLE"; echo ""
  verifier "$CIBLE"; echo ""
  if [ "$PROBLEMES" -gt 0 ]; then rouge "  $PROBLEMES point(s) à régler :$SOUCIS"; echo ""; echo "  Relance la commande d'installation : elle reprend là où ça a échoué."; echo ""; exit 1; fi
  vert "tout est en ordre"; echo ""; exit 0
fi

clear 2>/dev/null
cat <<'BAN'

  ╭──────────────────────────────────────────────╮
  │                                              │
  │            NMA  EDITOR                       │
  │            installation                      │
  │                                              │
  ╰──────────────────────────────────────────────╯

  Cette fenêtre affiche chaque étape.
  Compte 5 à 10 minutes si Derush Studio est déjà installé,
  20 à 30 minutes sinon (le modèle de transcription fait 1,4 Go).

  À SAVOIR :
  · aucun mot de passe administrateur ne sera demandé
  · tout s'installe dans ton dossier personnel
  · les montages utilisent TON abonnement Claude : il faut
    un abonnement Max pour monter plusieurs vidéos à la fois

BAN

# ----------------------------------------------------------------------------- 1. le Mac
etape 1 "Vérification de ton Mac"
[ "$(uname)" = "Darwin" ] || fatal "Cet outil fonctionne uniquement sur Mac."
ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ] && ARCH="arm64"
case "$ARCH" in arm64) NODE_ARCH="darwin-arm64"; FF_ARCH="arm64"; PUCE="Apple Silicon" ;; x86_64) NODE_ARCH="darwin-x64"; FF_ARCH="amd64"; PUCE="Intel" ;; *) fatal "Architecture inconnue : $ARCH" ;; esac
vert "Mac $PUCE · macOS $(sw_vers -productVersion)"
if ! xcode-select -p >/dev/null 2>&1; then
  echo ""; echo "  macOS doit d'abord installer ses outils de développement."; echo "  Une fenêtre va s'ouvrir : clique sur « Installer », attends la fin, puis relance la même commande."; echo ""
  xcode-select --install 2>/dev/null; exit 0
fi
vert "outils Apple présents"

# ----------------------------------------------------------------------------- 2. le jeton
etape 2 "Accès à l'application"
demander_jeton() { local msg="Colle ici le jeton d'accès que Tom t'a envoyé."; [ -n "${1:-}" ] && msg="⚠ $1

$msg"
  osascript <<AS 2>/dev/null
try
  set r to display dialog "$(as_txt "$msg")" with title "NMA Editor — installation" default answer "" with hidden answer buttons {"Annuler","Continuer"} default button "Continuer"
  return text returned of r
on error
  return "@@ANNULE@@"
end try
AS
}
JETON="${1:-}"; [ -n "$JETON" ] && gris "jeton fourni par la commande"; ERREUR=""
while true; do
  if [ -z "$JETON" ]; then echo "  Une fenêtre te demande le jeton fourni par Tom."; JETON=$(demander_jeton "$ERREUR")
    [ "$JETON" = "@@ANNULE@@" ] && fatal "Installation annulée." "Relance la commande quand tu auras le jeton."
    if [ -z "$JETON" ]; then ERREUR="Le champ était vide."; rouge "  ✗ $ERREUR"; continue; fi; fi
  JETON=$(printf '%s' "$JETON" | tr -d '[:space:]'); gris "vérification… (jeton de ${#JETON} caractères)"
  CFG=$(mktemp); chmod 600 "$CFG"; printf 'header = "Authorization: Bearer %s"\n' "$JETON" > "$CFG"
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 --config "$CFG" "https://api.github.com/repos/$DEPOT/contents/README.md"); rm -f "$CFG"
  case "$CODE" in
    200) vert "jeton valide"; armer_git "$JETON"; break ;;
    401) ERREUR="Jeton refusé : incomplet, mal collé ou expiré." ;;
    403) ERREUR="Jeton sans autorisation : il lui manque « Contents : Read-only » sur ce dépôt." ;;
    404) ERREUR="Ce jeton ne voit pas l'application : vérifie qu'il donne accès au dépôt nma-editor." ;;
    000) ERREUR="Pas de connexion internet." ;;
    *)   ERREUR="Réponse inattendue de GitHub (code $CODE)." ;;
  esac
  rouge "  ✗ $ERREUR"; gris "on réessaie — la fenêtre va revenir"; JETON=""
done

# ----------------------------------------------------------------------------- 3. emplacement
etape 3 "Où installer l'application"
mkdir -p "$HOME/.nma-editor"
ANCIEN="$(cat "$MARQUEUR" 2>/dev/null)"
if [ -n "$ANCIEN" ] && [ ! -f "$ANCIEN/server.mjs" ]; then
  case "$ANCIEN" in /Volumes/*) VOL="/Volumes/$(printf '%s' "${ANCIEN#/Volumes/}" | cut -d/ -f1)"
    [ -d "$VOL" ] || fatal "Le disque « $(basename "$VOL") » n'est pas branché." "Ton installation et tes projets sont dessus : branche-le et relance." ;; esac
  ANCIEN=""
fi
[ -z "$ANCIEN" ] && [ -f "$HOME/NMA Editor/server.mjs" ] && ANCIEN="$HOME/NMA Editor"
choisir_dossier() { osascript <<'AS' 2>/dev/null
try
  set d to choose folder with prompt "Dans quel dossier installer NMA Editor ?" default location (path to home folder)
  return POSIX path of d
on error
  return ""
end try
AS
}
if [ -n "$ANCIEN" ]; then
  echo "  Une installation existe déjà :"; gris "$ANCIEN"
  REP=$(osascript <<AS 2>/dev/null
try
  set r to display dialog "NMA Editor est déjà installé ici :

$ANCIEN" with title "NMA Editor — installation" buttons {"Annuler","Installer ailleurs","Mettre à jour ici"} default button "Mettre à jour ici"
  return button returned of r
on error
  return ""
end try
AS
)
  case "$REP" in
    "Mettre à jour ici") APP="$ANCIEN"; vert "mise à jour sur place — tes projets sont conservés" ;;
    "Installer ailleurs") CHOIX=$(choisir_dossier); [ -n "$CHOIX" ] || fatal "Installation annulée : aucun dossier choisi."
      APP="${CHOIX%/}/NMA Editor"; [ "$APP" = "$ANCIEN" ] && fatal "C'est le dossier de l'installation existante." "Relance et prends « Mettre à jour ici »." ;;
    *) fatal "Installation annulée." "Rien n'a été modifié." ;;
  esac
else
  echo "  Une fenêtre te demande de choisir un dossier (l'application ira dans un sous-dossier « NMA Editor »)."
  CHOIX=$(choisir_dossier); [ -n "$CHOIX" ] || fatal "Installation annulée : aucun dossier choisi." "Relance la commande et choisis un dossier."
  APP="${CHOIX%/}/NMA Editor"
fi
mkdir -p "$APP" 2>/dev/null || fatal "Impossible d'écrire dans « $APP »." "Choisis un dossier de ton dossier personnel."
[ -w "$APP" ] || fatal "« $APP » n'est pas modifiable." "Choisis un autre dossier."
printf '%s' "$APP" > "$MARQUEUR"
vert "$APP"

# ----------------------------------------------------------------------------- 4. outils
telecharger() { for essai in 1 2 3 4 5; do curl -sfL -C - --connect-timeout 20 --speed-limit 2048 --speed-time 60 -o "$2" "$1" && [ -s "$2" ] && return 0; [ "$essai" -lt 5 ] && gris "connexion interrompue — reprise $essai/4…"; sleep 3; done; return 1; }
etape 4 "Outils vidéo, Node et yt-dlp"
mkdir -p "$BIN" "$(dirname "$NODE_DIR")"
# Node COMPLET (node + npm + npx) : HyperFrames se lance avec npx.
if [ -x "$NODE_DIR/bin/node" ] && [ -x "$NODE_DIR/bin/npx" ]; then gris "Node déjà présent ($("$NODE_DIR/bin/node" --version))"; else
  gris "téléchargement de Node… (~30 Mo)"; T=$(mktemp -d)
  telecharger "https://nodejs.org/dist/$NODE_V/node-$NODE_V-$NODE_ARCH.tar.gz" "$T/n.tgz" || fatal "Téléchargement de Node impossible." "Vérifie ta connexion."
  tar -xzf "$T/n.tgz" -C "$T" 2>/dev/null || fatal "Archive Node illisible." "Relance la commande."
  rm -rf "$NODE_DIR"; mv "$T"/node-*/ "$NODE_DIR"; rm -rf "$T"
  { [ -x "$NODE_DIR/bin/node" ] && [ -x "$NODE_DIR/bin/npx" ]; } || fatal "Node n'a pas pu être installé."; vert "Node installé ($("$NODE_DIR/bin/node" --version))"; fi
[ -s "$BIN/node" ] || ln -sf "$NODE_DIR/bin/node" "$BIN/node"
for outil in ffmpeg ffprobe; do
  if [ -s "$BIN/$outil" ] && "$BIN/$outil" -version >/dev/null 2>&1; then gris "$outil déjà présent"; else
    gris "téléchargement de ${outil}… (~60 Mo)"; T=$(mktemp -d)
    telecharger "https://ffmpeg.martin-riedl.de/redirect/latest/macos/$FF_ARCH/release/$outil.zip" "$T/o.zip" || fatal "Téléchargement de $outil impossible." "Réessaie dans quelques minutes."
    unzip -qo "$T/o.zip" -d "$T"; f=$(find "$T" -name "$outil" -type f | head -1); [ -n "$f" ] && cp "$f" "$BIN/$outil" && chmod +x "$BIN/$outil"; rm -rf "$T"
    { [ -s "$BIN/$outil" ] && "$BIN/$outil" -version >/dev/null 2>&1; } || fatal "$outil n'a pas pu être installé."; vert "$outil installé"; fi
done
if [ -s "$BIN/yt-dlp" ] && "$BIN/yt-dlp" --version >/dev/null 2>&1; then gris "yt-dlp déjà présent ($("$BIN/yt-dlp" --version))"; else
  gris "téléchargement de yt-dlp… (~35 Mo)"
  telecharger "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" "$BIN/yt-dlp" || fatal "Téléchargement de yt-dlp impossible."
  chmod +x "$BIN/yt-dlp"; "$BIN/yt-dlp" --version >/dev/null 2>&1 || fatal "yt-dlp n'a pas pu être installé."; vert "yt-dlp installé"; fi

# ----------------------------------------------------------------------------- 5. Python
etape 5 "Moteur de transcription"
python_ok(){ [ -s "$VENV/bin/python" ] && [ "$("$VENV/bin/python" -c 'print(42)' 2>/dev/null)" = "42" ]; }
if python_ok; then gris "environnement Python déjà présent"; else
  [ -e "$VENV" ] && { gris "environnement Python inutilisable — reconstruction…"; rm -rf "$VENV"; }
  gris "création de l'environnement Python…"; mkdir -p "$(dirname "$VENV")"
  /usr/bin/python3 -m venv "$VENV" || fatal "Création de l'environnement Python impossible."; python_ok || fatal "L'environnement Python créé ne fonctionne pas."; fi
if "$VENV/bin/python" -c 'import faster_whisper' >/dev/null 2>&1; then gris "bibliothèques déjà présentes"; else
  gris "installation des bibliothèques… (2 à 5 minutes la première fois)"
  "$VENV/bin/pip" install --quiet --upgrade pip 2>/dev/null
  "$VENV/bin/pip" install --quiet "faster-whisper==1.2.1" "numpy==2.0.2" "av==15.1.0" "ctranslate2==4.8.1" \
    || fatal "Installation des bibliothèques échouée." "Vérifie ta connexion et relance."; fi
vert "bibliothèques prêtes"
MODELE_OK=non
for f in "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-medium"/snapshots/*/model.bin; do [ -f "$f" ] && [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 1000000000 ] && MODELE_OK=oui; done
if [ "$MODELE_OK" = oui ]; then gris "modèle de transcription déjà téléchargé"; else
  gris "téléchargement du modèle de transcription… (1,4 Go, 5 à 15 minutes, rien ne s'affiche pendant ce temps)"
  if "$VENV/bin/python" - <<'PY' 2>/dev/null
from faster_whisper import WhisperModel
WhisperModel("medium", device="cpu", compute_type="int8")
PY
  then vert "modèle prêt"; else gris "échec — il se téléchargera tout seul à la première transcription"; fi
fi

# ----------------------------------------------------------------------------- 6. Claude Code
etape 6 "Claude Code (les agents qui montent les vidéos)"
if C=$(trouver_claude); then gris "Claude Code déjà présent ($("$C" --version 2>/dev/null | head -1))"; else
  gris "installation de Claude Code (l'installeur officiel d'Anthropic)…"
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1
  C=$(trouver_claude) || fatal "Claude Code n'a pas pu être installé." "Installe-le à la main depuis https://claude.com/claude-code puis relance cette commande."
  vert "Claude Code installé"
fi
if claude_connecte; then vert "Claude Code est connecté à un compte"; else
  rouge "  ⚠ Claude Code n'est pas encore connecté à ton compte."
  echo "    À la fin de l'installation : ouvre le Terminal, tape  claude  puis Entrée,"
  echo "    et connecte-toi avec ton compte Claude (abonnement Max conseillé)."
fi

# ----------------------------------------------------------------------------- 7. l'application
etape 7 "Application"
if [ -d "$APP/.git" ]; then
  ranger_jeton "$APP"
  if git -C "$APP" -c credential.helper= fetch --quiet origin && git -C "$APP" reset --hard --quiet origin/main; then chmod 600 "$APP/.git/config"; vert "mise à jour effectuée"
  else chmod 600 "$APP/.git/config"; fatal "La mise à jour n'a pas pu être récupérée." "Vérifie ta connexion ou demande un nouveau jeton. L'application existante n'a pas été modifiée."; fi
else
  RESTE=$(ls -A "$APP" 2>/dev/null | grep -v -e '^\.DS_Store$' -e '^\._' || true)
  [ -z "$RESTE" ] || fatal "« $APP » n'est pas vide." "Vide ce dossier ou supprime-le, puis relance."
  gris "téléchargement de l'application…"
  git -c credential.helper= clone --quiet "https://github.com/$DEPOT.git" "$APP" || fatal "Téléchargement de l'application impossible." "Si le message dit « Write access to repository not granted », le jeton n'a pas la permission Contents sur nma-editor, ou un autre compte GitHub est enregistré dans le trousseau de ce Mac."
  ranger_jeton "$APP"; vert "application installée"
fi
cat > "$APP/Lancer NMA Editor.command" <<'LANCEUR'
#!/bin/bash
CIBLE="$0"; while [ -L "$CIBLE" ]; do CIBLE="$(readlink "$CIBLE")"; done
cd "$(dirname "$CIBLE")" || exit 1
export PATH="$HOME/.local/opt/node22/bin:$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:$PATH"
if curl -s http://localhost:4320/api/etat >/dev/null 2>&1; then echo "NMA Editor tourne déjà."; else mkdir -p "$HOME/.nma-editor"; node server.mjs > "$HOME/.nma-editor/serveur.log" 2>&1 & sleep 2; fi
open http://localhost:4320
echo "NMA Editor est ouvert dans le navigateur. Tu peux fermer cette fenêtre."
LANCEUR
chmod +x "$APP/Lancer NMA Editor.command" 2>/dev/null
raccourci_vers() { [ -d "$1" ] || return 1
  local S; S=$(mktemp); printf 'do shell script "/bin/bash " & quoted form of "%s/Lancer NMA Editor.command" & " >/dev/null 2>&1 &"\n' "$APP" > "$S"
  rm -rf "$1/NMA Editor.app" "$1/NMA Editor.command" 2>/dev/null
  if osacompile -o "$1/NMA Editor.app" "$S" >/dev/null 2>&1; then rm -f "$S"; return 0; fi; rm -f "$S"
  { printf '#!/bin/bash\nexec /bin/bash "%s/Lancer NMA Editor.command"\n' "$APP" > "$1/NMA Editor.command"; } 2>/dev/null || return 1; chmod +x "$1/NMA Editor.command" 2>/dev/null; }
if raccourci_vers "$HOME/Desktop"; then vert "raccourci créé sur le Bureau"; elif mkdir -p "$HOME/Applications" 2>/dev/null && raccourci_vers "$HOME/Applications"; then vert "raccourci créé dans ton dossier Applications"; else gris "raccourci impossible — le lanceur reste dans le dossier de l'application"; fi

# ----------------------------------------------------------------------------- 8. HyperFrames
etape 8 "HyperFrames (le moteur de montage et de rendu)"
HF_V=$(grep -o 'hyperframes@[0-9.]*' "$APP/gabarit/package.json" 2>/dev/null | head -1 | cut -d@ -f2)
[ -n "$HF_V" ] || HF_V="latest"
export PATH="$NODE_DIR/bin:$BIN:$PATH"
gris "préparation de HyperFrames $HF_V…"
( cd "$HOME" && npx --yes "hyperframes@$HF_V" --version >/dev/null 2>&1 ) && vert "HyperFrames prêt" || gris "HyperFrames se préparera au premier montage"
gris "navigateur de rendu… (~150 Mo la première fois)"
( cd "$HOME" && npx --yes "hyperframes@$HF_V" browser ensure >/dev/null 2>&1 ) && vert "navigateur de rendu prêt" || gris "échec — il se téléchargera au premier rendu"
gris "les designs s'installent au premier lancement de l'application"

# ----------------------------------------------------------------------------- 9. détourage
# RobustVideoMatting, sur la puce du Mac : 2 332 images en 1080x1920 en 118 s sur un M4 Pro, sans garder le décor
# derrière la tête comme l'outil de HyperFrames. PyTorch va dans le Python de macOS (celui que lancent les agents).
etape 9 "Détourage des vidéos (RVM, en local)"
if /usr/bin/python3 -E -c 'import torch, torchvision, numpy' >/dev/null 2>&1; then gris "PyTorch déjà présent"; else
  gris "installation de PyTorch… (environ 1 Go, 3 à 10 minutes la première fois)"
  /usr/bin/python3 -m pip install --user --quiet "torch==2.8.0" "torchvision==0.23.0" "numpy==2.0.2" \
    || fatal "Installation de PyTorch échouée." "Vérifie ta connexion et relance."
  /usr/bin/python3 -E -c 'import torch, torchvision' >/dev/null 2>&1 || fatal "PyTorch est installé mais Python ne le trouve pas."
fi
vert "PyTorch prêt"
mkdir -p "$RVM_DIR/weights"
if [ -f "$RVM_DIR/repo/model/__init__.py" ]; then gris "code de RVM déjà présent"; else
  rm -rf "$RVM_DIR/repo"
  git clone --quiet --depth 1 https://github.com/PeterL1n/RobustVideoMatting.git "$RVM_DIR/repo" || fatal "Téléchargement de RVM impossible." "Vérifie ta connexion et relance."
fi
POIDS="$RVM_DIR/weights/rvm_resnet50.pth"
if [ "$(wc -c < "$POIDS" 2>/dev/null || echo 0)" -gt 100000000 ]; then gris "modèle de détourage déjà téléchargé"; else
  gris "téléchargement du modèle de détourage… (108 Mo)"
  telecharger https://github.com/PeterL1n/RobustVideoMatting/releases/download/v1.0.0/rvm_resnet50.pth "$POIDS" \
    || fatal "Téléchargement du modèle de détourage impossible." "Vérifie ta connexion et relance."
fi
cp "$APP/outils/detourer.py" "$RVM_DIR/detourer.py" 2>/dev/null
vert "détourage RVM prêt"

# ----------------------------------------------------------------------------- terminé
echo ""; printf "\033[1m  VÉRIFICATION FINALE\033[0m\n"; verifier "$APP"; echo ""
if [ "$PROBLEMES" -gt 0 ]; then rouge "  $PROBLEMES point(s) à régler :$SOUCIS"; echo ""; echo "  Relance la commande : elle reprend là où ça a échoué."; echo ""
  exit 1; fi
printf "\033[1;32m  INSTALLATION TERMINÉE\033[0m\n"; echo ""
echo "  Pour lancer NMA Editor : double-clique sur « NMA Editor » (Bureau ou Applications)."
echo ""
# une application déjà ouverte garde l'ancien code en mémoire : on l'arrête pour que la version installée soit celle qui tourne
if curl -s http://localhost:4320/api/etat >/dev/null 2>&1; then lsof -ti tcp:4320 2>/dev/null | xargs kill 2>/dev/null; sleep 2; gris "application redémarrée avec la nouvelle version"; fi
bash "$APP/Lancer NMA Editor.command" >/dev/null 2>&1 &
exit 0
