#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    log_info "Prerequisites check passed ✓"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    if [ ! -f .env ]; then
        log_warn ".env file not found"
        log_info "Copying from .env.example..."
        cp .env.example .env
        log_warn "Please update .env with your configuration"
        exit 1
    fi
    
    # Source environment file
    export $(cat .env | grep -v '^#' | xargs)
    
    log_info "Environment setup complete ✓"
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p backend/uploaded_files
    mkdir -p backend/chroma_db_gemini
    mkdir -p ssl
    
    log_info "Directories created ✓"
}

# Generate SSL certificates (self-signed for development)
generate_ssl() {
    log_info "Checking SSL certificates..."
    
    if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
        log_warn "SSL certificates not found"
        log_info "Generating self-signed certificates..."
        
        openssl req -x509 -newkey rsa:4096 -nodes \
            -out ssl/cert.pem -keyout ssl/key.pem \
            -days 365 -subj "/CN=localhost"
        
        log_info "SSL certificates generated ✓"
    else
        log_info "SSL certificates found ✓"
    fi
}

# Build and start containers
deploy() {
    log_info "Building Docker images..."
    docker-compose build --no-cache
    
    log_info "Starting services..."
    docker-compose up -d
    
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check service health
    if docker-compose ps | grep -q "healthy"; then
        log_info "Services started successfully ✓"
    else
        log_warn "Some services may not be ready yet"
        log_info "Checking logs..."
        docker-compose logs
    fi
}

# Initialize database
init_database() {
    log_info "Initializing database..."
    
    # Wait for database to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T postgres pg_isready -U ${DB_USER} &> /dev/null; then
            log_info "PostgreSQL is ready ✓"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "PostgreSQL failed to start"
            exit 1
        fi
        sleep 1
    done
    
    log_info "Database initialization complete ✓"
}

# Health checks
health_check() {
    log_info "Running health checks..."
    
    # Check backend
    if curl -s http://localhost:8000/docs &> /dev/null; then
        log_info "Backend health check passed ✓"
    else
        log_warn "Backend health check failed"
    fi
    
    # Check frontend
    if curl -s http://localhost:3000 &> /dev/null; then
        log_info "Frontend health check passed ✓"
    else
        log_warn "Frontend health check failed"
    fi
    
    # Check PostgreSQL
    if docker-compose exec -T postgres pg_isready -U ${DB_USER} &> /dev/null; then
        log_info "PostgreSQL health check passed ✓"
    else
        log_error "PostgreSQL health check failed"
    fi
}

# Display service URLs
show_urls() {
    log_info "Deployment complete!"
    echo ""
    echo -e "${GREEN}Service URLs:${NC}"
    echo "  Frontend:           http://localhost:3000"
    echo "  Backend API:        http://localhost:8000"
    echo "  API Documentation:  http://localhost:8000/docs"
    echo "  PostgreSQL:         localhost:5432"
    echo "  ChromaDB:           localhost:8001"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Update .env with your API keys (GOOGLE_API_KEY, SERPAPI_API_KEY)"
    echo "  2. Configure your domain/SSL certificates in production"
    echo "  3. Set up backups for the database"
    echo "  4. Monitor application logs: docker-compose logs -f"
    echo ""
}

# Cleanup on error
cleanup() {
    log_error "Deployment failed. Cleaning up..."
    docker-compose down
    exit 1
}

# Main execution
main() {
    log_info "Starting GenAI-Stack production deployment..."
    echo ""
    
    trap cleanup ERR
    
    check_prerequisites
    setup_environment
    create_directories
    generate_ssl
    deploy
    init_database
    health_check
    show_urls
    
    log_info "All done! 🚀"
}

# Run main function
main "$@"
