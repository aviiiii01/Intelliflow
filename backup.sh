#!/bin/bash
set -e

# GenAI-Stack Backup & Restore Script

BACKUP_DIR="${BACKUP_DIR:-.backups}"
BACKUP_RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

show_usage() {
    cat << EOF
Usage: $0 {backup|restore|list|cleanup}

Commands:
  backup          Create a full backup of database and files
  restore <file>  Restore from a backup file
  list           List all available backups
  cleanup        Remove backups older than $BACKUP_RETENTION_DAYS days

Examples:
  $0 backup
  $0 restore $BACKUP_DIR/backup_20240412_120000.tar.gz
  $0 list
  $0 cleanup

Environment variables:
  BACKUP_DIR              Backup directory (default: .backups)
  BACKUP_RETENTION_DAYS   Days to keep backups (default: 30)
EOF
}

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory: $BACKUP_DIR"
}

# Backup database
backup_database() {
    local backup_file="$BACKUP_DIR/database_${TIMESTAMP}.sql"
    
    log_info "Backing up database..."
    
    if command -v docker &> /dev/null && docker-compose ps postgres &> /dev/null; then
        # Using Docker
        docker-compose exec -T postgres pg_dump -U ${DB_USER:-genai_user} genai_stack > "$backup_file"
    elif command -v psql &> /dev/null; then
        # Using direct PostgreSQL connection
        pg_dump -h localhost -U ${DB_USER:-genai_user} genai_stack > "$backup_file"
    else
        log_error "PostgreSQL tools not found"
        return 1
    fi
    
    log_info "Database backup saved: $backup_file"
    echo "$backup_file"
}

# Backup uploaded files
backup_files() {
    local backup_file="$BACKUP_DIR/files_${TIMESTAMP}.tar.gz"
    
    log_info "Backing up uploaded files..."
    
    if [ -d "backend/uploaded_files" ]; then
        tar -czf "$backup_file" \
            -C backend uploaded_files \
            -C . backend/chroma_db_gemini 2>/dev/null || true
        log_info "Files backup saved: $backup_file"
        echo "$backup_file"
    else
        log_warn "No uploaded files directory found"
    fi
}

# Backup configuration
backup_config() {
    local backup_file="$BACKUP_DIR/config_${TIMESTAMP}.tar.gz"
    
    log_info "Backing up configuration..."
    
    tar -czf "$backup_file" .env docker-compose.yml nginx.conf 2>/dev/null || true
    
    log_info "Configuration backup saved: $backup_file"
    echo "$backup_file"
}

# Create full backup
backup_full() {
    log_info "Starting full backup..."
    create_backup_dir
    
    local backup_file="$BACKUP_DIR/backup_${TIMESTAMP}.tar.gz"
    local temp_dir=$(mktemp -d)
    
    # Create temp backup structure
    mkdir -p "$temp_dir/database"
    mkdir -p "$temp_dir/files"
    mkdir -p "$temp_dir/config"
    
    # Backup each component
    if command -v docker &> /dev/null && docker-compose ps postgres &> /dev/null; then
        docker-compose exec -T postgres pg_dump -U ${DB_USER:-genai_user} genai_stack > "$temp_dir/database/genai_stack.sql"
    elif command -v psql &> /dev/null; then
        pg_dump -h localhost -U ${DB_USER:-genai_user} genai_stack > "$temp_dir/database/genai_stack.sql"
    fi
    
    # Backup uploaded files
    if [ -d "backend/uploaded_files" ]; then
        cp -r backend/uploaded_files "$temp_dir/files/" 2>/dev/null || true
        cp -r backend/chroma_db_gemini "$temp_dir/files/" 2>/dev/null || true
    fi
    
    # Backup configuration (without sensitive data)
    cp .env "$temp_dir/config/.env.backup" 2>/dev/null || true
    cp docker-compose.yml "$temp_dir/config/" 2>/dev/null || true
    cp nginx.conf "$temp_dir/config/" 2>/dev/null || true
    
    # Create tarball
    cd "$temp_dir"
    tar -czf "$backup_file" .
    cd - > /dev/null
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_info "Full backup completed: $backup_file"
    log_info "Backup size: $(du -h $backup_file | cut -f1)"
    
    # Show restore command
    echo ""
    echo "To restore this backup, run:"
    echo "  $0 restore $backup_file"
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warn "Restoring from backup: $backup_file"
    echo "WARNING: This will overwrite your current data!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    log_info "Extracting backup..."
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore database
    if [ -f "$temp_dir/database/genai_stack.sql" ]; then
        log_info "Restoring database..."
        
        if command -v docker &> /dev/null && docker-compose ps postgres &> /dev/null; then
            docker-compose exec -T postgres psql -U ${DB_USER:-genai_user} genai_stack < "$temp_dir/database/genai_stack.sql"
        elif command -v psql &> /dev/null; then
            psql -h localhost -U ${DB_USER:-genai_user} genai_stack < "$temp_dir/database/genai_stack.sql"
        fi
        
        log_info "Database restored"
    fi
    
    # Restore files
    if [ -d "$temp_dir/files/uploaded_files" ]; then
        log_info "Restoring uploaded files..."
        rm -rf backend/uploaded_files
        cp -r "$temp_dir/files/uploaded_files" backend/
        log_info "Uploaded files restored"
    fi
    
    if [ -d "$temp_dir/files/chroma_db_gemini" ]; then
        log_info "Restoring ChromaDB data..."
        rm -rf backend/chroma_db_gemini
        cp -r "$temp_dir/files/chroma_db_gemini" backend/
        log_info "ChromaDB data restored"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_info "Restore completed!"
    log_info "Restart services to apply changes: docker-compose restart"
}

# List backups
list_backups() {
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
        log_warn "No backups found in $BACKUP_DIR"
        return 0
    fi
    
    log_info "Available backups:"
    echo ""
    ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{printf "  %-40s %10s  %s %s %s\n", $9, $5, $6, $7, $8}'
    echo ""
}

# Cleanup old backups
cleanup_old_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "Backup directory does not exist"
        return 0
    fi
    
    log_info "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
    
    local count=0
    while IFS= read -r file; do
        rm -f "$file"
        log_info "Removed: $(basename $file)"
        ((count++))
    done < <(find "$BACKUP_DIR" -type f -mtime +$BACKUP_RETENTION_DAYS)
    
    if [ $count -eq 0 ]; then
        log_info "No old backups to remove"
    else
        log_info "Removed $count old backup(s)"
    fi
}

# Schedule backup with cron (optional)
setup_cron() {
    local script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    local cron_job="0 2 * * * cd $PWD && $script_path backup > /tmp/genai-backup.log 2>&1"
    
    log_info "Adding cron job for daily backups at 2 AM..."
    
    # Check if already exists
    if crontab -l 2>/dev/null | grep -q "$script_path backup"; then
        log_info "Cron job already exists"
        return 0
    fi
    
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    log_info "Cron job added"
    log_info "Backups will run daily at 2 AM"
}

# Main execution
case "${1:-}" in
    backup)
        backup_full
        ;;
    restore)
        if [ -z "$2" ]; then
            log_error "Please specify backup file"
            show_usage
            exit 1
        fi
        restore_backup "$2"
        ;;
    list)
        list_backups
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    setup-cron)
        setup_cron
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
