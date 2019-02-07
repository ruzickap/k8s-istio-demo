#!/usr/bin/env bash

################################################
# include the magic
################################################
test -f ./demo-magic.sh || curl --silent https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh > demo-magic.sh
. ./demo-magic.sh -n

################################################
# Configure the options
################################################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=40

# Uncomment to run non-interactively
#export PROMPT_TIMEOUT=1

# If this is running under CI disable any user interaction (not to stop on the "wait" funcion)
[ "$CI" == "true" ] && export PROMPT_TIMEOUT=1

# No wait
export NO_WAIT=true

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "
DEMO_PROMPT="${GREEN}➜ ${CYAN}$ "

# hide the evidence
clear

sed -n '/^```bash$/,/^```$/p;/^-----$/p' README.md | \
sed -n '/^\[ -f \$PWD\/kubeconfig.conf \] && export KUBECONFIG=/,$p' | sed '1s/^/```bash\n/' | \
sed -e 's/^-----$/\
p  ""\
p  "################################################################################################### Press <ENTER> to continue"\
wait\
/' \
-e 's/^```bash$/\
pe '"'"'/' \
-e 's/^```$/'"'"'/' \
> README.sh

source README.sh
