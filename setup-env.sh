#!/bin/bash
# Environment Setup Helper Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Setup environment file
setup_env_file() {
    log_section "Environment Configuration Setup"
    
    if [ -f .env ]; then
        log_warn ".env file already exists"
        read -p "Do you want to reconfigure? (yes/no): " reconfigure
        if [ "$reconfigure" != "yes" ]; then
            return 0
        fi
    fi
    
    # Copy template
    cp .env.example .env
    log_info "Created .env from template"
    
    # Database configuration
    log_section "Database Configuration"
    
    read -p "Enter PostgreSQL username (default: genai_user): " db_user
    db_user=${db_user:-genai_user}
    
    read -p "Generate random database password? (yes/no): " gen_pass
    if [ "$gen_pass" = "yes" ]; then
        db_pass=$(generate_password)
        log_info "Generated password: $db_pass"
    else
        read -sp "Enter database password: " db_pass
        echo ""
    fi
    
    # Update .env
    sed -i "s/^DB_USER=.*/DB_USER=$db_user/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$db_pass/" .env
    
    # API Keys setup
    log_section "API Keys Configuration"
    
    echo ""
    echo "You need to configure two API keys:"
    echo "1. Google API Key (for Gemini)"
    echo "2. SerpAPI Key (for web search)"
    echo ""
    
    read -p "Do you have the API keys? (yes/no): " has_keys
    
    if [ "$has_keys" = "yes" ]; then
        read -p "Enter Google API Key: " google_key
        sed -i "s/^GOOGLE_API_KEY=.*/GOOGLE_API_KEY=$google_key/" .env
        
        read -p "Enter SerpAPI Key: " serpapi_key
        sed -i "s/^SERPAPI_API_KEY=.*/SERPAPI_API_KEY=$serpapi_key/" .env
        
        log_info "API keys configured"
    else
        log_warn "API keys not configured - application will have limited functionality"
        echo "Get your keys from:"
        echo "  - Google: https://ai.google.dev/"
        echo "  - SerpAPI: https://serpapi.com/"
    fi
    
    # Frontend URL
    log_section "Frontend Configuration"
    
    read -p "Enter your domain/server URL (default: http://localhost:8000): " frontend_url
    frontend_url=${frontend_url:-http://localhost:8000}
    sed -i "s|^REACT_APP_API_URL=.*|REACT_APP_API_URL=$frontend_url|" .env
    
    log_info "Environment configuration complete"
    
    # Display summary
    echo ""
    echo "Configuration Summary:"
    echo "  Database User: $db_user"
    echo "  Database Password: (set)"
    echo "  Frontend URL: $frontend_url"
    echo "  API Keys: $([ "$has_keys" = "yes" ] && echo "Configured" || echo "Not configured")"
}

# Validate environment
validate_env() {
    log_section "Validating Environment"
    
    local valid=true
    
    # Check required variables
    if grep -q "^GOOGLE_API_KEY=$" .env; then
        log_warn "GOOGLE_API_KEY not set"
        valid=false
    else
        log_info "GOOGLE_API_KEY configured"
    fi
    
    if grep -q "^SERPAPI_API_KEY=$" .env; then
        log_warn "SERPAPI_API_KEY not set"
        valid=false
    else
        log_info "SERPAPI_API_KEY configured"
    fi
    
    if grep -q "^DB_PASSWORD=your_secure" .env; then
        log_error "DB_PASSWORD not changed from default"
        valid=false
    else
        log_info "DB_PASSWORD configured"
    fi
    
    # Check sensitive passwords in .env
    if grep -q "password\|key\|secret" .env | grep -qv "^#"; then
        log_info ".env appears to have passwords configured"
    fi
    
    if [ "$valid" = true ]; then
        log_info "Environment validation passed"
    else
        log_error "Please fix the errors above before deploying"
        return 1
    fi
}

# Test Docker setup
test_docker() {
    log_section "Testing Docker Setup"
    
    if ! command_exists docker; then
        log_error "Docker is not installed"
        log_info "Install Docker from: https://docs.docker.com/get-docker/"
        return 1
    fi
    log_info "Docker found: $(docker --version)"
    
    if ! command_exists docker-compose; then
        log_error "Docker Compose is not installed"
        log_info "Install Docker Compose from: https://docs.docker.com/compose/install/"
        return 1
    fi
    log_info "Docker Compose found: $(docker-compose --version)"
    
    # Test Docker daemon
    if ! docker ps >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon"
        log_info "Start Docker with: sudo systemctl start docker"
        return 1
    fi
    log_info "Docker daemon is running"
    
    log_info "Docker setup is valid"
}

# Install dependencies
install_dependencies() {
    log_section "Checking Dependencies"
    
    local missing=false
    
    # Check Docker
    if ! command_exists docker; then
        log_error "Docker not found"
        missing=true
    else
        log_info "Docker: $(docker --version)"
    fi
    
    # Check Docker Compose
    if ! command_exists docker-compose; then
        log_error "Docker Compose not found"
        missing=true
    else
        log_info "Docker Compose: $(docker-compose --version)"
    fi
    
    # Check curl
    if ! command_exists curl; then
        log_error "curl not found"
        missing=true
    else
        log_info "curl: found"
    fi
    
    # Check openssl
    if ! command_exists openssl; then
        log_error "openssl not found"
        missing=true
    else
        log_info "openssl: found"
    fi
    
    if [ "$missing" = true ]; then
        log_warn "Some dependencies are missing"
        log_info "For Ubuntu/Debian:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install curl openssl"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sudo sh get-docker.sh"
        return 1
    else
        log_info "All dependencies found"
    fi
}

# Create required directories
create_directories() {
    log_section "Setting Up Directories"
    
    log_info "Creating directories..."
    mkdir -p backend/uploaded_files
    mkdir -p backend/chroma_db_gemini
    mkdir -p .backups
    mkdir -p ssl
    
    # Set permissions
    chmod 755 *.sh 2>/dev/null || true
    
    log_info "Directories created successfully"
}

# Generate SSL certificates
generate_ssl_certs() {
    log_section "SSL Certificate Setup"
    
    if [ -f ssl/cert.pem ] && [ -f ssl/key.pem ]; then
        log_info "SSL certificates already exist"
        read -p "Regenerate? (yes/no): " regen
        if [ "$regen" != "yes" ]; then
            return 0
        fi
    fi
    
    if ! command_exists openssl; then
        log_error "openssl is required to generate certificates"
        return 1
    fi
    
    log_info "Generating self-signed SSL certificates..."
    
    openssl req -x509 -newkey rsa:4096 -nodes \
        -out ssl/cert.pem -keyout ssl/key.pem \
        -days 365 -subj "/CN=localhost" 2>/dev/null
    
    chmod 600 ssl/key.pem
    chmod 644 ssl/cert.pem
    
    log_info "SSL certificates generated"
    log_warn "Note: These are self-signed certificates for development"
    log_info "For production, use Let's Encrypt or your own certificates"
}

# Quick test deployment
quick_test() {
    log_section "Quick Deployment Test"
    
    log_info "Building Docker images..."
    docker-compose build --no-cache 2>&1 | tail -5
    
    log_info "Starting services..."
    docker-compose up -d
    
    log_info "Waiting for services to start..."
    sleep 10
    
    log_info "Checking service status..."
    docker-compose ps
    
    log_info "Testing API endpoint..."
    if curl -s http://localhost:8000/docs > /dev/null; then
        log_info "API is responding"
    else
        log_warn "API is not responding yet"
    fi
    
    log_info "Test deployment completed"
    log_info "Services running at:"
    echo "  Frontend: http://localhost:3000"
    echo "  Backend: http://localhost:8000"
    echo "  API Docs: http://localhost:8000/docs"
}

# Show menu
show_menu() {
    echo ""
    echo -e "${BLUE}GenAI-Stack Environment Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Setup environment file (.env)"
    echo "2. Validate environment configuration"
    echo "3. Install/check dependencies"
    echo "4. Create required directories"
    echo "5. Generate SSL certificates"
    echo "6. Run quick test deployment"
    echo "7. Full setup (all steps)"
    echo "8. Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "Enter your choice (1-8): " choice
    echo ""
    
    case $choice in
        1) setup_env_file ;;
        2) validate_env ;;
        3) install_dependencies ;;
        4) create_directories ;;
        5) generate_ssl_certs ;;
        6) quick_test ;;
        7) 
            install_dependencies && \
            create_directories && \
            setup_env_file && \
            generate_ssl_certs && \
            validate_env && \
            log_section "Setup Complete!" && \
            log_info "Ready to deploy with: ./deploy.sh"
            ;;
        8) exit 0 ;;
        *) log_error "Invalid choice" ;;
    esac
}

# Main execution
main() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        GenAI-Stack Production Environment Setup           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ "${1:-}" = "auto" ]; then
        # Automated setup
        log_info "Running automated setup..."
        install_dependencies && \
        create_directories && \
        setup_env_file && \
        generate_ssl_certs && \
        validate_env
    else
        # Interactive menu
        while true; do
            show_menu
        done
    fi
}

# Run main
main "$@"
