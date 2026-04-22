#!/usr/bin/env bash
# AWS — S3, Lambda, RDS, EC2, CloudFront, etc.
# Native CLI: `aws`. Caches creds at ~/.aws/credentials (profile-based).

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_aws_status() {
  aws sts get-caller-identity >/dev/null 2>&1
}

shiplane_service_aws_onboard() {
  if ! command -v aws >/dev/null 2>&1; then
    echo "   aws CLI not installed — install with: brew install awscli"
    return 1
  fi

  if shiplane_service_aws_status; then
    local identity
    identity="$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null || echo unknown)"
    echo "   ✓ already authed as $identity"
  else
    echo "   launching 'aws configure' — you'll need:"
    echo "     - AWS Access Key ID"
    echo "     - AWS Secret Access Key"
    echo "     - default region (e.g. us-east-1)"
    echo "     - default output format (json)"
    echo
    echo "   mint programmatic keys at:"
    echo "     https://console.aws.amazon.com/iam/home#/security_credentials"
    echo
    aws configure
    if ! shiplane_service_aws_status; then
      echo "   ✗ aws configure completed but sts.GetCallerIdentity still fails"
      return 1
    fi
  fi

  local default_region default_profile
  default_region="$(aws configure get region 2>/dev/null || echo '')"
  default_profile="${AWS_PROFILE:-default}"

  shiplane_save_creds "$(jq -n --arg r "$default_region" --arg p "$default_profile" \
    '{aws:{default_region:$r,default_profile:$p}}')"
  echo "   ✓ aws authed (region: ${default_region:-unset}, profile: $default_profile)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_aws_onboard
fi
