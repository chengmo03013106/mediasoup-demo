#!/usr/bin/env bash
# ============================================================================
#  mediasoup-demo one-click stop script (macOS)
#
#  What it does: stop mediasoup SFU server and frontend Vite service
#                by killing processes listening on ports 4443/44444/5555.
#
#  Usage: ./stop-all.sh
# ============================================================================

echo "============================================================"
echo "  Stopping mediasoup-demo services..."
echo "============================================================"

for port in 4443 44444 5555; do
	pids="$(lsof -ti :"$port" 2>/dev/null || true)"
	if [ -n "$pids" ]; then
		echo "[INFO] Killing process on port $port: $pids"
		# shellcheck disable=SC2086
		kill $pids 2>/dev/null || true
	fi
done

# Give processes a moment to exit, then force-kill any survivors.
sleep 1
for port in 4443 44444 5555; do
	pids="$(lsof -ti :"$port" 2>/dev/null || true)"
	if [ -n "$pids" ]; then
		echo "[INFO] Force killing process on port $port: $pids"
		# shellcheck disable=SC2086
		kill -9 $pids 2>/dev/null || true
	fi
done

echo
echo "[OK] services stopped"
