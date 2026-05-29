#!/usr/bin/env bash
#
# deploy.sh — Create DRAFT WordPress posts for the two AI-security articles on
# diverzeent.com, sideload their (watermark-free) featured images, and print
# preview URLs.
#
# WHY THIS SCRIPT EXISTS
#   The cloud sandbox these articles were authored in cannot reach
#   diverzeent.com (egress allowlist returns "Host not in allowlist") or the
#   image generation host. Run this from any machine/environment that CAN reach
#   diverzeent.com (your laptop, or a Claude Code environment whose network
#   policy allowlists the domain).
#
# WHAT IT DOES (idempotent-ish, draft-only by default)
#   For each article:
#     1. Sideloads the featured image (Option A) into WP Media via the REST API.
#        WordPress fetches/stores the image server-side, so the gen-host URL only
#        needs to be reachable by THIS script's machine, not by WP.
#        (We download then multipart-upload the bytes — most robust.)
#     2. Extracts the article body HTML (between the DEPLOY BLOCK markers).
#     3. Creates a POST as status=draft via the dze deploy gateway, setting
#        title, slug, category, AIOSEO title/description/keyphrase, and
#        featured_media.
#     4. Prints the WordPress edit + preview URLs.
#
# REQUIREMENTS: bash, curl, python3 (for safe JSON encoding — avoids \uXXXX
#   escapes in HTML, per the gateway's "no Unicode escape sequences" rule).
#
# USAGE
#   ./deploy.sh                 # create both drafts
#   ./deploy.sh mythos          # only the Claude Mythos draft
#   ./deploy.sh glasswing       # only the Project Glasswing draft
#   PUBLISH=1 ./deploy.sh       # publish live instead of draft (use with care)
#
# OVERRIDABLE ENV
#   GW_SECRET   deploy gateway secret           (default: documented value)
#   WP_AUTH     WP REST Basic auth (base64)     (default: documented value)
#   PUBLISH     "1" => status=publish, else draft
#
set -euo pipefail

# ----------------------------- configuration --------------------------------
SITE="https://www.diverzeent.com"
GW_URL="${SITE}/?dze_deploy_api=1"
GW_SECRET="${GW_SECRET:-dze_gw_2026_K9mPxQrT}"
# WP REST Basic auth (Di-VErZe app password), from DZE Featured Image Creator notes:
WP_AUTH="${WP_AUTH:-RGktVmVyWmU6ZHpHTSBacW9MIEdSM0cgOFRxNiAwRkdpIEpVUUc=}"
STATUS="draft"; [ "${PUBLISH:-0}" = "1" ] && STATUS="publish"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMGDIR="$HERE/articles/images"
mkdir -p "$IMGDIR"

# ------------------------------- article data -------------------------------
# fields: key | html_file | slug | category | focus_kw | meta_title | meta_desc | img_url | img_file | img_alt
mythos_file="$HERE/articles/claude-mythos-ai-too-dangerous-2026.html"
mythos_slug="claude-mythos-ai-too-dangerous-2026"
mythos_cat="AI & Tech"
mythos_kw="Claude Mythos AI 2026"
mythos_title="Claude Mythos AI 2026: The Model Anthropic Locked Away | Di-VErZe E.N.T"
mythos_desc="Claude Mythos AI 2026: Anthropic locked away an AI that found thousands of zero-day exploits. What it means for Atlanta and your devices. Read the breakdown."
mythos_imgurl="https://d8j0ntlcm91z4.cloudfront.net/user_35nYfXwqHWygOROpoVeEpmuWLBa/hf_20260529_125204_1a2cce23-5a9c-45a1-a91d-f8c472dbf739.png"
mythos_imgfile="$IMGDIR/claude-mythos-ai-too-dangerous-2026-featured.jpg"
mythos_imgalt="Claude Mythos AI 2026 Anthropic zero-day vulnerability model locked away on dark circuit background - Di-VErZe E.N.T"

glass_file="$HERE/articles/anthropic-ai-security-bugs-project-glasswing-2026.html"
glass_slug="anthropic-ai-security-bugs-project-glasswing-2026"
glass_cat="AI & Tech"
glass_kw="Anthropic AI security 2026"
glass_title="Anthropic AI Security 2026: 10,000 Bugs Found in a Month | Di-VErZe E.N.T"
glass_desc="Anthropic AI security 2026: Project Glasswing found 10,000 critical software bugs in a month. What it means for Atlanta users and your data. Read now."
glass_imgurl="https://d8j0ntlcm91z4.cloudfront.net/user_35nYfXwqHWygOROpoVeEpmuWLBa/hf_20260529_125216_ef1e7edd-d895-497a-a166-f1c865680471.png"
glass_imgfile="$IMGDIR/anthropic-ai-security-bugs-project-glasswing-2026-featured.jpg"
glass_imgalt="Anthropic AI security 2026 Project Glasswing Claude vulnerability scan on dark circuit background - Di-VErZe E.N.T"

# ------------------------------- helpers ------------------------------------
log(){ printf '\n\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null   || die "curl is required"
command -v python3 >/dev/null|| die "python3 is required"

# Extract the HTML between the DEPLOY BLOCK markers (this is the post body).
extract_body(){
  python3 - "$1" <<'PY'
import sys,re
src=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"DEPLOY BLOCK START =+ -->(.*)<!-- =+ DEPLOY BLOCK END",src,re.S)
if not m: sys.exit("could not find DEPLOY BLOCK markers")
sys.stdout.write(m.group(1).strip())
PY
}

# Download the gen image to a local 1200x630 JPG (crop-to-fill). If Pillow is
# unavailable, fall back to the raw download (WP will crop on its own).
fetch_image(){
  local url="$1" out="$2" tmp; tmp="$(mktemp).img"
  log "Downloading featured image -> $(basename "$out")"
  curl -fsSL -A "$UA" --max-time 120 -o "$tmp" "$url" || die "image download failed: $url"
  python3 - "$tmp" "$out" <<'PY' || cp "$tmp" "$out"
import sys
src,out=sys.argv[1],sys.argv[2]
from PIL import Image
im=Image.open(src).convert("RGB"); W,H=im.size; t=1200/630; ar=W/H
if ar>t: nw=int(H*t); x=(W-nw)//2; im=im.crop((x,0,x+nw,H))
else:    nh=int(W/t); y=(H-nh)//2; im=im.crop((0,y,W,y+nh))
im.resize((1200,630),Image.LANCZOS).save(out,"JPEG",quality=88,optimize=True)
print("cropped to 1200x630",out)
PY
  rm -f "$tmp"
}

# Upload a local image to WP Media, echo the numeric media id.
upload_media(){
  local file="$1" title="$2" alt="$3" resp id
  log "Uploading to WP media: $(basename "$file")"
  resp="$(curl -fsS -A "$UA" --max-time 180 \
      -H "Authorization: Basic ${WP_AUTH}" \
      -F "file=@${file};type=image/jpeg" \
      -F "title=${title}" \
      -F "alt_text=${alt}" \
      "${SITE}/wp-json/wp/v2/media")" || die "media upload failed"
  id="$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')"
  [ -n "$id" ] || die "no media id in response: ${resp:0:300}"
  printf '%s' "$id"
}

# Create the post via the deploy gateway. Echoes the raw gateway JSON.
create_post(){
  local slug="$1" title="$2" body_file="$3" cat="$4" kw="$5" mtitle="$6" mdesc="$7" media_id="$8"
  log "Creating ${STATUS} post via gateway: /${slug}/"
  # Build the JSON payload in python with ensure_ascii=False so the HTML body
  # contains literal UTF-8 (no \uXXXX), per the gateway's content rule.
  # All values are passed via env to avoid any quoting/escaping pitfalls.
  local payload
  payload="$(GW_SECRET="$GW_SECRET" STATUS="$STATUS" P_TITLE="$title" P_SLUG="$slug" \
             P_CAT="$cat" P_KW="$kw" P_MTITLE="$mtitle" P_MDESC="$mdesc" \
             P_MEDIA="$media_id" P_BODY_FILE="$body_file" \
    python3 - <<'PY'
import json, os
body = open(os.environ["P_BODY_FILE"], encoding="utf-8").read()
media = os.environ.get("P_MEDIA", "")
payload = {
    "secret": os.environ["GW_SECRET"],
    "action": "create_post",
    "post_type": "post",
    "status": os.environ["STATUS"],
    "title": os.environ["P_TITLE"],
    "slug": os.environ["P_SLUG"],
    "content": body,
    "category": os.environ["P_CAT"],
    "featured_media": int(media) if media.isdigit() else None,
    "aioseo": {
        "title": os.environ["P_MTITLE"],
        "description": os.environ["P_MDESC"],
        "keyphrase": os.environ["P_KW"],
    },
}
print(json.dumps(payload, ensure_ascii=False))
PY
)"
  curl -fsS -A "$UA" --max-time 180 \
    -H "Content-Type: application/json" \
    "$GW_URL" --data-binary "$payload"
}

# Full pipeline for one article.
deploy_one(){
  local pfx="$1"
  local file slug cat kw title desc imgurl imgfile imgalt
  eval "file=\${${pfx}_file}";   eval "slug=\${${pfx}_slug}"
  eval "cat=\${${pfx}_cat}";     eval "kw=\${${pfx}_kw}"
  eval "title=\${${pfx}_title}"; eval "desc=\${${pfx}_desc}"
  eval "imgurl=\${${pfx}_imgurl}"; eval "imgfile=\${${pfx}_imgfile}"
  eval "imgalt=\${${pfx}_imgalt}"

  [ -f "$file" ] || die "article file missing: $file"

  fetch_image "$imgurl" "$imgfile"
  local media_id; media_id="$(upload_media "$imgfile" "${title%% |*} — Di-VErZe E.N.T" "$imgalt")"
  log "WP media id = $media_id"

  local body; body="$(mktemp)"; extract_body "$file" > "$body"
  local out; out="$(create_post "$slug" "$title" "$body" "$cat" "$kw" "$title" "$desc" "$media_id")"
  rm -f "$body"

  printf '%s\n' "$out"
  echo "$out" | python3 - "$slug" <<'PY' || true
import sys,json
slug=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: d={}
pid=d.get("post_id") or d.get("id") or ""
ok=d.get("success", d.get("ok"))
print(f"\n  success : {ok}")
print(f"  post_id : {pid}")
print(f"  edit    : https://www.diverzeent.com/wp-admin/post.php?post={pid}&action=edit" if pid else "  edit    : (see response)")
print(f"  preview : https://www.diverzeent.com/{slug}/?preview=true")
PY
}

# -------------------------------- main --------------------------------------
target="${1:-all}"
log "Mode: status=${STATUS}  target=${target}"
case "$target" in
  mythos)    deploy_one mythos ;;
  glasswing) deploy_one glass ;;
  all)       deploy_one mythos; deploy_one glass ;;   # origin story first, then sequel
  *) die "unknown target '$target' (use: mythos | glasswing | all)";;
esac

log "Done. Review the drafts in WP admin before publishing."
echo "Reminder: Mythos <-> Glasswing cross-links only resolve once BOTH are published." >&2
