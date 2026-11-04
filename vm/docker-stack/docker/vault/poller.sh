#!/bin/bash
# INTENTIONALLY VULNERABLE: anything dropped into /shared/task.sh gets
# executed with THIS container's privileges (root), no validation at
# all -- the "container escape" from relay's RCE into vault.
while true; do
    if [ -f /shared/task.sh ]; then
        bash /shared/task.sh > /shared/task_output.txt 2>&1 || true
        rm -f /shared/task.sh
    fi
    sleep 2
done
