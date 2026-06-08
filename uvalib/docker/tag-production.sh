#!/bin/bash
# Apply a production release tag to both ECR and git simultaneously.
# Must be run from within the git repository being tagged.
#
# Usage: tag-production.sh [-s SUFFIX] [-n] [commit]
#   commit     git SHA or ref to tag (default: HEAD)
#   -s SUFFIX  append suffix to tag name
#              e.g. -s security_patch → production_2026_06_08_security_patch
#   -n|--dry-run  dry run — show what would happen without making changes
#   -h         show this help
#
# The ECR repository name is derived from the git remote URL (org/repo).
# Override by setting ECR_REPO in the environment.

set -euo pipefail

# Resolve AWS command.
# Prefers credentials already in the environment (inside an aws-vault exec session,
# or a plain AWS_PROFILE). Falls back to aws-vault if AWS_VAULT_PROFILE is set.
# Otherwise calls aws directly and lets it fail naturally if unconfigured.
aws_run() {
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_PROFILE:-}" ]]; then
        aws "$@"
    elif command -v aws-vault &>/dev/null && [[ -n "${AWS_VAULT_PROFILE:-}" ]]; then
        aws-vault exec "${AWS_VAULT_PROFILE}" -- aws "$@"
    else
        aws "$@"
    fi
}

DRYRUN=false
SUFFIX=""

usage() {
    echo "Usage: $(basename "$0") [-s SUFFIX] [-n] [commit]"
    echo "  -s SUFFIX      tag suffix (e.g. 'security_patch')"
    echo "  -n, --dry-run  dry run"
    echo "  -h, --help     this help"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s) SUFFIX="_${2:?-s requires an argument}"; shift 2 ;;
        -n|--dry-run) DRYRUN=true; shift ;;
        -h|--help) usage; shift ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage 1 ;;
        *) break ;;
    esac
done

COMMIT="${1:-HEAD}"

# Resolve to full SHA
SHA=$(git rev-parse "$COMMIT")

# Derive ECR repo from git remote unless overridden (github.com:org/repo.git → org/repo)
ECR_REPO="${ECR_REPO:-$(git remote get-url origin | sed -E 's|.*[:/]([^/]+/[^/]+)\.git$|\1|')}"

PROD_TAG="production_$(date +%Y_%m_%d)${SUFFIX}"
GITCOMMIT_TAG="gitcommit-${SHA}"

echo "Commit:   ${SHA}"
echo "ECR repo: ${ECR_REPO}"
echo "Tag:      ${PROD_TAG}"
echo ""

# Guard: git tag must not already exist
if git tag | grep -qx "$PROD_TAG"; then
    echo "Error: git tag '${PROD_TAG}' already exists." >&2
    echo "Use -s SUFFIX to distinguish multiple releases on the same date." >&2
    exit 1
fi

# Guard: ECR tag must not already exist
EXISTING_ECR=$(aws_run ecr batch-get-image \
    --repository-name "$ECR_REPO" \
    --image-ids imageTag="$PROD_TAG" \
    --query 'images[0].imageId.imageTag' \
    --output text 2>/dev/null || true)
if [[ -n "$EXISTING_ECR" && "$EXISTING_ECR" != "None" ]]; then
    echo "Error: ECR tag '${PROD_TAG}' already exists." >&2
    exit 1
fi

# Fetch the image manifest for the target commit
MANIFEST=$(aws_run ecr batch-get-image \
    --repository-name "$ECR_REPO" \
    --image-ids imageTag="$GITCOMMIT_TAG" \
    --query 'images[0].imageManifest' \
    --output text 2>/dev/null || true)

if [[ -z "$MANIFEST" || "$MANIFEST" == "None" ]]; then
    echo "Error: no ECR image found for ${GITCOMMIT_TAG}" >&2
    echo "Has this commit been built by CI yet?" >&2
    exit 1
fi

if $DRYRUN; then
    echo "[dry run] Would apply ECR tag '${PROD_TAG}' to ${ECR_REPO}:${GITCOMMIT_TAG}"
    echo "[dry run] Would create git tag '${PROD_TAG}' → ${SHA}"
    echo "[dry run] Would push git tag to origin"
    exit 0
fi

echo "Tagging ECR image..."
aws_run ecr put-image \
    --repository-name "$ECR_REPO" \
    --image-tag "$PROD_TAG" \
    --image-manifest "$MANIFEST" \
    --output json > /dev/null

echo "Creating git tag..."
git tag "$PROD_TAG" "$SHA"

echo "Pushing git tag to origin..."
git push origin "$PROD_TAG"

echo ""
echo "Done: ${PROD_TAG}"
