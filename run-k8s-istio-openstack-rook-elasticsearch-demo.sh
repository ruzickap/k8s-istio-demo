#!/bin/bash -eux

sed -n '/^```bash$/,/^```$/p' README.md | sed '/^```*/d' | sed -n '/^terraform init -var-file=terrafrom/,/^kubectl get -l app=fluent-bit svc,pods --all-namespaces -o wide$/p' > README.sh

source README.sh

sed -n '/^Configure port forwarding for Kibana:$/,/^* Select @timestamp/p' README.md
