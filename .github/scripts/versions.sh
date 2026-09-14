#!/usr/bin/env bash
set -euo pipefail

readme=${1:-README.md}
cd "$(git rev-parse --show-toplevel)"

grep -q '^<!-- versions:start -->$' "${readme}" || { echo "${readme} has no <!-- versions:start --> marker" >&2; exit 1; }
grep -q '^<!-- versions:end -->$' "${readme}" || { echo "${readme} has no <!-- versions:end --> marker" >&2; exit 1; }

default_java=$(sed -n 's/^ARG JAVA_IMAGE=amazoncorretto:\([0-9]*\)\..*/\1/p' Dockerfile)
generated=$(mktemp)
trap 'rm -f "${generated}"' EXIT

docker buildx bake --progress=quiet --print | jq -r --arg default_java "${default_java}" '
  def titles: {paper: "Paper", fabric: "Fabric", forge: "Forge", neoforge: "NeoForge"};
  def loader_header: {paper: "Paper build", fabric: "Fabric loader", forge: "Forge", neoforge: "NeoForge"};
  def loader($a):
    if $a.PAPER_BUILD then $a.PAPER_BUILD
    elif $a.FABRIC_VERSION then "\($a.FABRIC_VERSION) (installer \($a.INSTALLER_VERSION))"
    elif $a.FORGE_VERSION then ($a.FORGE_VERSION | sub("^[^-]+-"; ""))
    else $a.NEOFORGE_VERSION end;
  [.target[] | {
      variant: .target,
      image: (.tags[0] | sub(":[^:]*$"; "")),
      mc: (.tags[0] | sub("^.*:"; "")),
      loader: loader(.args),
      java: ((.args.JAVA_IMAGE // "") | capture("amazoncorretto:(?<v>[0-9]+)\\.").v // $default_java),
      tags: (.tags | map(sub("^.*:"; "")))
    }]
  | group_by(.variant)
  | map(
      (sort_by(.mc | split(".") | map(tonumber)) | reverse) as $rows
      | "### \(titles[$rows[0].variant])\n\n`\($rows[0].image)`\n\n"
        + "| Minecraft | \(loader_header[$rows[0].variant]) | Java | Tags |\n| --- | --- | --- | --- |\n"
        + ($rows | map("| \(.mc) | \(.loader) | \(.java) | \(.tags | map("`\(.)`") | join(", ")) |") | join("\n"))
    )
  | join("\n\n")
' > "${generated}"

awk -v generated="${generated}" '
  $0 == "<!-- versions:start -->" {
    print
    print ""
    while ((getline line < generated) > 0) print line
    print ""
    skip = 1
    next
  }
  $0 == "<!-- versions:end -->" { skip = 0 }
  !skip { print }
' "${readme}" > "${readme}.tmp"
mv "${readme}.tmp" "${readme}"
