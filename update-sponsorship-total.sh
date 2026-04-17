#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${GH_SPONSORS_PAT:-}" ]]; then
  echo "GH_SPONSORS_PAT is required"
  exit 1
fi

response="$(
  curl -fsSL -X POST https://api.github.com/graphql \
    -H "Authorization: bearer $GH_SPONSORS_PAT" \
    -H "Content-Type: application/json" \
    -d '{"query":"query { viewer { totalSponsorshipAmountAsSponsorInCents } }"}'
)"

cents="$(jq -r '.data.viewer.totalSponsorshipAmountAsSponsorInCents // empty' <<<"$response")"

if [[ -z "$cents" ]]; then
  echo "Failed to read sponsorship total from GraphQL response"
  echo "$response"
  exit 1
fi

display_amount="$(awk "BEGIN {
  amount = int($cents / 100)
  printf \"$%d USD\", amount
}")"
encoded_amount="${display_amount// /%20}"
encoded_amount="${encoded_amount//$/%24}"
badge_url="https://img.shields.io/badge/Open%20Source%20Given-${encoded_amount}-2ea44f?style=for-the-badge&logo=githubsponsors&logoColor=white"

replacement="$(cat <<EOF
<!-- sponsorship total start -->

## 🤝 Giving Back
![Auto Updated](https://img.shields.io/badge/Generated%20by-GitHub%20Actions-blue?logo=githubactions)

> I try to support the maintainers behind the open source tools I use. It is not about the total, just a small reminder that a little from more of us would make a real difference.

![Open source sponsorship total]($badge_url)

<!-- sponsorship total end -->
EOF
)"

README_REPLACEMENT="$replacement" perl -0pi -e 's{<!-- sponsorship total start -->.*?<!-- sponsorship total end -->}{$ENV{README_REPLACEMENT}}s' README.md
