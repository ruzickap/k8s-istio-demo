#!/bin/bash -eux

sed -n '/^Download Terraform components:$/,/^## Istio architecture and features$/p' README.md | \
sed -n '/^```bash$/,/^```$/p' | \
sed '/^```*/d' > README.sh

source README.sh

sed -n '/^Configure port forwarding for Kibana:$/,/^* Select @timestamp/p' README.md
