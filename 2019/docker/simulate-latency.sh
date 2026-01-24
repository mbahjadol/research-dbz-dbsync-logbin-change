#!/bin/bash
TARGET=$1   # source-db or target-db
ACTION=$2   # add, loss, reset, slow
case $ACTION in
  slow)
    docker exec -u 0 $TARGET tc qdisc add dev eth0 root netem delay 800ms 200ms distribution normal
    ;;
  loss20)
    docker exec -u 0 $TARGET tc qdisc add dev eth0 root netem loss 20%
    ;;
  loss50)
    docker exec -u 0 $TARGET tc qdisc add dev eth0 root netem loss 50%
    ;;
  loss100)
    docker exec -u 0 $TARGET tc qdisc add dev eth0 root netem loss 100%
    ;;
  reset)
    docker exec -u 0 $TARGET tc qdisc del dev eth0 root
    ;;
  *)
    echo "Usage: $0 {source-db|target-db} {slow|loss20|loss50|loss100|reset}"
    echo "  slow  - 🐌 add latency"
    echo "  loss20  - 🚫 add packet 20% loss"
    echo "  loss50  - 🚫 add packet 50% loss"
    echo "  loss100  - 🚫 add packet 100% loss"
    echo "  reset - 🔄️ reset all network impairments"
    exit 1
    ;;
esac
exit 0
