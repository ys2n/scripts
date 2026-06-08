#!/bin/bash
# Peek inside a tagged container from the given ECR repo.
# Usage: peek-repo-image.sh <image> [tag]
#   image  e.g. uvalib/drupal-library (no leading slash)
#   tag    optional; if omitted, interactively select from ECR tags (fzf or fallback)

set -e
REPO="${ECR_REPO:-115119339709.dkr.ecr.us-east-1.amazonaws.com}"
IMAGE="${1:?Usage: $0 <image> [tag]   e.g. $0 uvalib/drupal-library latest}"
FULL_IMAGE=
VAULT_PROFILE="${VAULT_PROFILE:-staging}"

# Run a command with AWS credentials.
# Prefers credentials already in the environment; falls back to aws-vault.
vault_run() {
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_PROFILE:-}" ]]; then
    "$@"
  elif command -v aws-vault &>/dev/null; then
    aws-vault exec "$VAULT_PROFILE" -- "$@"
  else
    "$@"
  fi
}

list_ecr_tags() {
  vault_run aws ecr describe-images \
    --repository-name "$IMAGE" \
    --query 'imageDetails[*].imageTags[]' \
    --output text 2>/dev/null | tr '\t' '\n' | sort -u
}

pick_tag() {
  local tags
  tags=$(list_ecr_tags)
  if [[ -z "$tags" ]]; then
    echo "No tags found for ${IMAGE}" >&2
    return 1
  fi
  if command -v fzf &>/dev/null; then
    echo "$tags" | fzf --height 40% --reverse --no-multi
  else
    echo "Install 'fzf' for fuzzy tag selection. Listing tags:" >&2
    local num=0
    local -a arr
    while IFS= read -r t; do arr+=( "$t" ); (( num++ )) || true; done <<< "$tags"
    printf '%s\n' "${arr[@]}" | nl >&2
    echo "" >&2
    read -r -p "Enter tag or number (1-${num}): " ans
    if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= num )); then
      echo "${arr[ans-1]}"
    else
      echo "$ans"
    fi
  fi
}

# ECR login (required before listing or pulling)
vault_run /Users/ys2n/Code/uvalib/terraform-infrastructure/scripts/ecr-authenticate.ksh

if [[ -n "${2:-}" ]]; then
  TAG="$2"
else
  TAG=$(pick_tag)
  [[ -z "$TAG" ]] && exit 1
fi

FULL_IMAGE="${REPO}/${IMAGE}:${TAG}"
echo "Peeking into ${FULL_IMAGE}"
docker run --rm -it --entrypoint /bin/bash "${FULL_IMAGE}"
