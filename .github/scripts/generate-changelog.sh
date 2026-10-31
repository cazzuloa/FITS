#!/usr/bin/env bash
#
# Génère une section de CHANGELOG à partir des commits Git.
#
# Usage :
#   .github/scripts/generate-changelog.sh <tag> [changelog] [fichier-section]
#
# Exemple :
#   .github/scripts/generate-changelog.sh v0.3.0
#
# Le script :
#   1. récupère les commits entre le tag précédent et <tag> ;
#   2. classe chaque commit par type (feat, fix, docs, ...) puis par fichier ;
#   3. insère la nouvelle section en haut de CHANGELOG.md.
#
# Les préfixes de commit reconnus sont :
#   feat      -> Added          fix       -> Fixed
#   docs      -> Documentation  remove    -> Removed
#   autre/none -> Edit
#
set -euo pipefail

TAG="${1:?Usage: $0 <tag> [changelog] [fichier-section]}"
CHANGELOG="${2:-CHANGELOG.md}"
SECTION_OUT="${3:-}"

# Fichiers qui ne doivent pas apparaître dans le changelog.
IGNORE_RE='^(CHANGELOG\.md|\.github/|fits$|test$)'

fail() { echo "Erreur : $*" >&2; exit 1; }

git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null \
  || fail "le tag ${TAG} n'existe pas."

VERSION="V${TAG#[vV]}"
DATE="$(git log -1 --format=%cs "${TAG}")"

# Tag précédent (v0.2.0, V1.0.0, ...). Vide si c'est le premier tag.
PREV_TAG="$(git describe --tags --abbrev=0 \
  --match 'v[0-9]*' --match 'V[0-9]*' \
  "${TAG}^" 2>/dev/null || true)"

if [[ -n "${PREV_TAG}" ]]; then
  RANGE="${PREV_TAG}..${TAG}"
  echo "Commits analysés : ${RANGE}" >&2
else
  RANGE="${TAG}"
  echo "Aucun tag précédent : historique complet de ${TAG}" >&2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

: > "$work/entries"

# Chaque ligne produite a le format : rang<US>titre<US>fichier<US>description
# (US = unit separator, \x1f).
while IFS=$'\x1f' read -r sha subject; do
  [[ -z "${sha}" ]] && continue

  desc="${subject}"
  prefix=""
  if [[ "${subject}" =~ ^([A-Za-z]+)(\([^\)]*\))?[[:space:]]*:[[:space:]]*(.*)$ ]]; then
    prefix="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    desc="${BASH_REMATCH[3]}"
  fi
  [[ -z "${desc}" ]] && desc="${subject}"

  # Majuscule initiale, pour rester proche du style existant.
  desc="$(printf '%s' "${desc:0:1}" | tr '[:lower:]' '[:upper:]')${desc:1}"

  case "${prefix}" in
    feat|feature)              heading="Added";         rank=1 ;;
    fix|bugfix|hotfix)         heading="Fixed";         rank=2 ;;
    docs|doc)                  heading="Documentation"; rank=4 ;;
    remove|revert|deprecate)   heading="Removed";       rank=5 ;;
    *)                         heading="Edit";          rank=3 ;;
  esac

  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue
    [[ "${file}" =~ ${IGNORE_RE} ]] && continue
    printf '%s\x1f%s\x1f%s\x1f%s\n' \
      "${rank}" "${heading}" "${file}" "${desc}"
  done < <(git diff-tree --root --no-commit-id --name-only -r "${sha}") \
    >> "$work/entries"
done < <(git log --no-merges --reverse --format='%H%x1f%s' "${RANGE}")

# Tri par type, puis par fichier, puis par description. Déduplication.
if [[ -s "$work/entries" ]]; then
  sort -t $'\x1f' -k1,1n -k3,3 -k4,4 "$work/entries" \
    | awk -F'\x1f' '!seen[$0]++' \
    > "$work/sorted"
else
  : > "$work/sorted"
fi

# Rendu de la section.
{
  printf '## %s - %s\n' "${VERSION}" "${DATE}"

  if [[ -s "$work/sorted" ]]; then
    awk -F'\x1f' '
      {
        heading = $2
        file    = $3
        desc    = $4

        if (heading != last_heading) {
          print "### " heading
          last_heading = heading
          last_file = ""
        }
        if (file != last_file) {
          print "* " file
          last_file = file
        }
        print "    - " desc
      }
    ' "$work/sorted"
  else
    printf '### Edit\n* Aucun changement notable.\n'
  fi

  printf '\n'
} > "$work/section.md"

# Création du fichier s'il n'existe pas encore.
if [[ ! -f "${CHANGELOG}" ]]; then
  cat > "${CHANGELOG}" <<'EOF'
# Changelog

Toutes les modifications notables de ce projet CLI seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com),
et ce projet adhère à la [Version Sémantique](https://semver.org).

EOF
fi

# Supprime une éventuelle section déjà présente pour cette version,
# afin que le script puisse être relancé sans créer de doublon.
awk -v ver="${VERSION}" '
  BEGIN {
    gsub(/\./, "\\.", ver)
    pattern = "^##[[:space:]]+" ver "([[:space:]]|$)"
  }
  $0 ~ pattern { skip = 1; next }
  skip && /^##[[:space:]]/ { skip = 0 }
  !skip { print }
' "${CHANGELOG}" > "$work/base"

# Sépare l'en-tête du reste du fichier.
awk '/^##[[:space:]]/ { exit } { print }' "$work/base" > "$work/head"
awk 'BEGIN { found = 0 } /^##[[:space:]]/ { found = 1 } found { print }' \
  "$work/base" > "$work/rest"

# Enlève les lignes vides finales de l'en-tête.
awk '
  { line[NR] = $0 }
  END {
    last = NR
    while (last > 0 && line[last] ~ /^[[:space:]]*$/) last--
    for (i = 1; i <= last; i++) print line[i]
  }
' "$work/head" > "$work/head.trim"

# Nouvelle section en haut, suivie de l'historique existant.
{
  cat "$work/head.trim"
  printf '\n'
  cat "$work/section.md"
  cat "$work/rest"
} > "$work/merged"

if [[ -n "${SECTION_OUT}" ]]; then
  cp "$work/section.md" "${SECTION_OUT}"
fi

mv "$work/merged" "${CHANGELOG}"

echo "Section ${VERSION} générée dans ${CHANGELOG}." >&2
