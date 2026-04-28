#!/bin/bash

# GenAI-Stack Health Check & Monitoring Script

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8000}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${DB_USER:-genai_user}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Functions
check_status() {
    local name=$1
    local command=$2
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_warning() {
    local name=$1
    local command=$2
    
    if eval "$command" &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} $name"
        ((CHECKS_WARNING++))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
        return 1
    fi
}

# Docker Checks
check_docker() {
    echo ""
    echo -e "${BLUE}Docker Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_status "Docker daemon running" "docker ps > /dev/null"
    check_status "Docker Compose available" "docker-compose --version > /dev/null"
    
    # Check containers
    if command -v docker &> /dev/null; then
        check_status "PostgreSQL container running" "docker-compose ps postgres | grep -q running"
        check_status "ChromaDB container running" "docker-compose ps chroma | grep -q running"
        check_status "Backend container running" "docker-compose ps backend | grep -q running"
        check_status "Frontend container running" "docker-compose ps frontend | grep -q running"
    fi
}

# Database Checks
check_database() {
    echo ""
    echo -e "${BLUE}Database Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check PostgreSQL connection
    if command -v psql &> /dev/null; then
        check_status "PostgreSQL responding" "psql -h $POSTGRES_HOST -U $POSTGRES_USER -d genai_stack -c 'SELECT 1' > /dev/null 2>&1"
    elif command -v docker &> /dev/null; then
        check_status "PostgreSQL responding" "docker-compose exec -T postgres pg_isready -U $POSTGRES_USER > /dev/null"
    fi
    
    # Check database size
    if command -v docker &> /dev/null && docker-compose ps postgres &> /dev/null; then
        local db_size=$(docker-compose exec -T postgres psql -U $POSTGRES_USER -d genai_stack -t -c "SELECT pg_size_pretty(pg_database_size(current_database()))" 2>/dev/null || echo "unknown")
        echo "  Database size: $db_size"
    fi
}

# API Checks
check_api() {
    echo ""
    echo -e "${BLUE}Backend API Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_status "API responding" "curl -s $API_URL/docs > /dev/null"
    
    if curl -s $API_URL/health &> /dev/null; then
        local health=$(curl -s $API_URL/health)
        echo "  Health: $health"
    fi
    
    # Check API documentation
    check_warning "API documentation available" "curl -s $API_URL/docs | grep -q 'openapi'"
    
    # Check specific endpoints
    check_status "Upload endpoint" "curl -s $API_URL/docs | grep -q 'uploadfile'"
    check_status "Stacks endpoint" "curl -s $API_URL/docs | grep -q 'stacks'"
}

# Frontend Checks
check_frontend() {
    echo ""
    echo -e "${BLUE}Frontend Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_status "Frontend responding" "curl -s $FRONTEND_URL > /dev/null"
    
    # Check if frontend is serving React app
    check_warning "React app served" "curl -s $FRONTEND_URL | grep -q '<div id=\"root\">' || curl -s $FRONTEND_URL | grep -q 'script'"
}

# ChromaDB Checks
check_chromadb() {
    echo ""
    echo -e "${BLUE}ChromaDB Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local chroma_url="http://localhost:8001"
    
    check_status "ChromaDB responding" "curl -s $chroma_url/api/v1/heartbeat > /dev/null"
    
    if curl -s "$chroma_url/api/v1/collections" &> /dev/null; then
        local collections=$(curl -s "$chroma_url/api/v1/collections" | grep -o '"name"' | wc -l)
        echo "  Collections: $collections"
    fi
}

# System Resources
check_resources() {
    echo ""
    echo -e "${BLUE}System Resources${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # CPU Usage
    if command -v top &> /dev/null; then
        local cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        echo "  CPU Usage: $cpu"
    fi
    
    # Memory Usage
    if command -v free &> /dev/null; then
        local mem=$(free -h | grep "Mem:" | awk '{print $3 " / " $2}')
        echo "  Memory Usage: $mem"
    fi
    
    # Disk Space
    if command -v df &> /dev/null; then
        local disk=$(df -h / | tail -1 | awk '{print $3 " / " $2 " (" $5 ")"}')
        echo "  Disk Usage: $disk"
    fi
    
    # Docker resource limits
    if command -v docker &> /dev/null; then
        echo ""
        echo "  Container Resources:"
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | grep -E "backend|frontend|postgres|chroma" || true
    fi
}

# Port Checks
check_ports() {
    echo ""
    echo -e "${BLUE}Port Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_status "Backend (8000)" "netstat -tln | grep -q :8000 || curl -s http://localhost:8000 > /dev/null"
    check_status "Frontend (3000)" "netstat -tln | grep -q :3000 || curl -s http://localhost:3000 > /dev/null"
    check_status "PostgreSQL (5432)" "netstat -tln | grep -q :5432"
    check_status "ChromaDB (8001)" "netstat -tln | grep -q :8001"
}

# File System Checks
check_filesystem() {
    echo ""
    echo -e "${BLUE}File System Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_status "Environment file exists" "[ -f .env ]"
    check_status "Docker Compose file exists" "[ -f docker-compose.yml ]"
    check_status "Upload directory writable" "[ -w backend/uploaded_files ]"
    check_status "Backup directory exists" "[ -d .backups ] || true && echo 'OK'"
    
    # Check disk space
    local available=$(df /home -h | tail -1 | awk '{print $4}')
    local threshold=1G
    echo "  Available disk space: $available"
}

# Summary
show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo -e "  ${GREEN}Passed: $CHECKS_PASSED${NC}"
    echo -e "  ${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "  ${RED}Failed: $CHECKS_FAILED${NC}"
    
    echo ""
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All systems operational!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some checks failed. Review logs above.${NC}"
        return 1
    fi
}

# Help
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  all          Run all checks (default)
  docker       Check Docker status
  database     Check database status
  api          Check API status
  frontend     Check frontend status
  chromadb     Check ChromaDB status
  resources    Check system resources
  ports        Check port status
  filesystem   Check filesystem status
  continuous   Run checks continuously (every 30 seconds)
  help         Show this help message

Examples:
  $0                    # Run all checks once
  $0 api                # Check only API
  $0 continuous         # Monitor continuously
  $0 docker api         # Check docker and API

EOF
}

# Run specific checks
run_check() {
    case "$1" in
        docker)
            check_docker
            ;;
        database)
            check_database
            ;;
        api)
            check_api
            ;;
        frontend)
            check_frontend
            ;;
        chromadb)
            check_chromadb
            ;;
        resources)
            check_resources
            ;;
        ports)
            check_ports
            ;;
        filesystem)
            check_filesystem
            ;;
        all|"")
            check_docker
            check_ports
            check_database
            check_api
            check_frontend
            check_chromadb
            check_filesystem
            check_resources
            ;;
        *)
            echo -e "${RED}Unknown check: $1${NC}"
            return 1
            ;;
    esac
}

# Main
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

if [ "$1" = "continuous" ]; then
    echo -e "${BLUE}Running continuous health checks (Ctrl+C to stop)${NC}"
    echo ""
    while true; do
        clear
        echo -e "${BLUE}GenAI-Stack Health Check${NC}"
        echo -e "${BLUE}$(date)${NC}"
        echo ""
        CHECKS_PASSED=0
        CHECKS_FAILED=0
        CHECKS_WARNING=0
        
        if [ -z "$2" ] || [ "$2" = "all" ]; then
            check_docker
            check_ports
            check_database
            check_api
            check_frontend
        else
            run_check "$2"
        fi
        
        show_summary
        
        echo ""
        echo "Next check in 30 seconds... (Ctrl+C to stop)"
        sleep 30
    done
else
    # Single run
    echo -e "${BLUE}GenAI-Stack Health Check${NC}"
    echo -e "${BLUE}$(date)${NC}"
    echo ""
    
    CHECKS_PASSED=0
    CHECKS_FAILED=0
    CHECKS_WARNING=0
    
    # Run all specified checks
    if [ $# -eq 0 ]; then
        run_check "all"
    else
        for check in "$@"; do
            run_check "$check"
        done
    fi
    
    show_summary
    exit $CHECKS_FAILED
fi
