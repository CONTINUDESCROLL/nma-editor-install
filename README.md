# NMA Editor — installation

Outil de montage de Newmask Agency : les reels sortis de Derush Studio sont montés
automatiquement, en parallèle, chacun dans un design (tier list, nuit étoilée,
basique…), puis relus sur une timeline de retours et exportés.

Cette page ne sert qu'à **installer** l'outil. Un jeton fourni par Tom est nécessaire
pour accéder à l'application.

---

## Avant d'installer

- Un **Mac** (Apple Silicon conseillé).
- Un **compte Claude** avec un abonnement Max : les montages utilisent ton abonnement.

## Installer

Ouvre le **Terminal** (⌘ + Espace, tape « Terminal », Entrée), colle cette ligne
et appuie sur Entrée :

```bash
curl -fsSL https://raw.githubusercontent.com/CONTINUDESCROLL/nma-editor-install/main/install.sh | bash
```

Une fenêtre te demandera le **jeton d'accès** que Tom t'a envoyé, puis le **dossier**
où installer l'application (elle ira dans un sous-dossier « NMA Editor »). Aucun mot
de passe administrateur n'est demandé.

L'installeur met en place : Node, ffmpeg, yt-dlp, le moteur de transcription (le même
que Derush Studio), Claude Code, HyperFrames et son navigateur de rendu, puis
l'application et un raccourci « NMA Editor » sur le Bureau. Les designs s'installent
au premier lancement.

**Une seule chose à faire à la main** si l'installeur te le dit : ouvrir le Terminal,
taper `claude`, Entrée, et te connecter avec ton compte Claude.

## Mettre à jour

Rien à faire : quand une nouvelle version existe, un bouton vert « Mise à jour
disponible » apparaît en haut de l'application. Un clic, et elle redémarre à jour,
avec les nouveaux designs.

## Vérifier une installation

```bash
curl -fsSL https://raw.githubusercontent.com/CONTINUDESCROLL/nma-editor-install/main/install.sh | bash -s -- --verifier
```
