#!/usr/bin/env bash
# =============================================================================
# local-dev.sh – Common development tasks
# =============================================================================
set -euo pipefail

CMD="${1:-help}"

case "$CMD" in
  up)
    echo "▶ Starting local stack…"
    docker compose up -d postgres redis
    sleep 2
    docker compose up -d backend
    sleep 3
    docker compose up -d frontend
    echo "✅ Stack running:"
    echo "   Frontend  → http://localhost:3000"
    echo "   Backend   → http://localhost:8000"
    echo "   Postgres  → localhost:5432"
    echo "   Redis     → localhost:6379"
    ;;

  seed)
    echo "▶ Seeding database with sample cars…"
    docker compose --profile seed up seed
    ;;

  down)
    docker compose down
    ;;

  reset)
    echo "⚠️  Destroying all local volumes and containers…"
    docker compose down -v --remove-orphans
    ;;

  logs)
    SERVICE="${2:-}"
    docker compose logs -f $SERVICE
    ;;

  migrate)
    echo "▶ Running Alembic migrations…"
    docker compose exec backend alembic upgrade head
    ;;

  test-api)
    echo "▶ Testing API endpoints…"
    BASE="http://localhost:8000"
    echo -n "Health: "
    curl -sf "$BASE/health" | jq .status
    echo -n "Cars: "
    curl -sf "$BASE/api/cars?limit=3" | jq '.cars | length'
    echo -n "Inquiry: "
    curl -sf -X POST "$BASE/api/inquiries" \
      -H "Content-Type: application/json" \
      -d '{"name":"Test","email":"test@test.com","message":"Hello"}' | jq .status
    echo "✅ All endpoints responding"
    ;;

  help|*)
    echo ""
    echo "Usage: ./scripts/local-dev.sh <command>"
    echo ""
    echo "Commands:"
    echo "  up          Start full local stack (postgres, redis, backend, frontend)"
    echo "  seed        Seed database with sample car inventory"
    echo "  down        Stop all containers"
    echo "  reset       Destroy containers + volumes (clean slate)"
    echo "  logs [svc]  Tail logs (all services or specific one)"
    echo "  migrate     Run Alembic database migrations"
    echo "  test-api    Smoke test API endpoints"
    echo ""
    ;;
esac
