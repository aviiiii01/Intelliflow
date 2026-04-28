# GenAI-Stack Production Deployment - Complete Setup

## 📦 What's Included

Your production deployment package includes:

### Core Deployment Files
- **docker-compose.yml** - Complete multi-container orchestration setup
- **Dockerfile files** - Optimized container images for all services
- **nginx.conf** - Production-grade reverse proxy configuration

### Deployment Scripts
- **deploy.sh** - Automated one-command deployment (recommended)
- **backup.sh** - Database and file backup/restore utilities
- **health-check.sh** - Monitoring and health check script
- **install-systemd.sh** - Alternative non-Docker systemd installation

### Documentation
- **PRODUCTION_DEPLOYMENT.md** - Comprehensive deployment guide
- **QUICK_DEPLOY.md** - Fast 5-minute setup guide
- **.env.example** - Environment configuration template

---

## 🚀 Quick Start (Recommended)

### 1. Prepare Your Server
```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Copy project to server
scp -r GenAI-Stack user@your-server:/opt/
ssh user@your-server
cd /opt/GenAI-Stack
```

### 2. Configure Environment
```bash
# Copy example configuration
cp .env.example .env

# Edit with your API keys
nano .env
# Required values to update:
# - DB_PASSWORD=your_secure_password
# - GOOGLE_API_KEY=your_key
# - SERPAPI_API_KEY=your_key
# - REACT_APP_API_URL=https://your-domain.com (for production)
```

### 3. Deploy
```bash
# Make script executable and run
chmod +x deploy.sh
./deploy.sh
```

Done! Your application will be running on:
- **Frontend**: http://your-server:3000
- **Backend API**: http://your-server:8000
- **API Docs**: http://your-server:8000/docs

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────┐
│               Your Domain (HTTPS)               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │         Nginx Reverse Proxy              │  │
│  │  (Port 80 → 443, Load Balancing)        │  │
│  └──────────────────────────────────────────┘  │
│          ↓                           ↓          │
│  ┌──────────────────┐      ┌──────────────────┐│
│  │  Frontend (React)│      │  Backend (FastAPI)│
│  │   Port 3000      │      │    Port 8000     ││
│  └──────────────────┘      └──────────────────┘│
│          ↓                           ↓          │
│          │        ┌──────────────────┘          │
│          │        │                             │
│  ┌───────┴────────┴──────────────────────────┐ │
│  │       PostgreSQL Database                 │ │
│  │   (Persistent Storage, Port 5432)        │ │
│  └─────────────────────────────────────────── │
│          │                                    │
│  ┌───────┴──────────────────────────────────┐ │
│  │       ChromaDB Vector Database           │ │
│  │   (Knowledge Base, Port 8001)           │ │
│  └─────────────────────────────────────────── │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🔧 Available Commands

### Deployment & Lifecycle
```bash
# Deploy application
./deploy.sh

# Start services
docker-compose up -d

# Stop services
docker-compose stop

# Restart services
docker-compose restart

# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Rebuild containers
docker-compose build --no-cache
```

### Backup & Restore
```bash
# Create full backup
./backup.sh backup

# List backups
./backup.sh list

# Restore from backup
./backup.sh restore .backups/backup_20240412_120000.tar.gz

# Setup automated daily backups (cron)
./backup.sh setup-cron

# Cleanup old backups (>30 days)
./backup.sh cleanup
```

### Monitoring & Health
```bash
# Run all health checks
./health-check.sh

# Check specific service
./health-check.sh api
./health-check.sh database
./health-check.sh frontend

# Continuous monitoring (every 30s)
./health-check.sh continuous
```

### Database Management
```bash
# Access database
docker-compose exec postgres psql -U genai_user -d genai_stack

# Backup database
docker-compose exec postgres pg_dump -U genai_user genai_stack > backup.sql

# Restore database
docker-compose exec -T postgres psql -U genai_user genai_stack < backup.sql

# Check database size
docker-compose exec postgres psql -U genai_user -d genai_stack -c "SELECT pg_size_pretty(pg_database_size(current_database()))"
```

---

## 🔐 Security Checklist

### Before Production
- [ ] Changed database password in .env
- [ ] Set DEBUG=false in .env
- [ ] Generated SSL certificates
- [ ] Configured firewall (allow: 80, 443, 22)
- [ ] Updated CORS origins for your domain
- [ ] Set up automated backups
- [ ] Changed secret keys/API keys

### Regular Maintenance
- [ ] Monitor logs daily
- [ ] Check disk space
- [ ] Verify backups are working
- [ ] Update containers monthly: `docker-compose pull && docker-compose up -d`
- [ ] Review access logs for suspicious activity
- [ ] Test backup restoration process

### Network Security
```bash
# Restrict firewall to required ports
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 📈 Performance Tuning

### For Small Deployments (< 100 users)
- Default Docker Compose setup is sufficient
- 1 backend worker is fine
- PostgreSQL default config works

### For Medium Deployments (100-1000 users)
```bash
# Scale backend workers
# Edit docker-compose.yml backend service:
CMD ["uvicorn", "app.main:app", "--workers", "4"]

# Enable database connection pooling
SQLALCHEMY_POOL_SIZE=20
SQLALCHEMY_MAX_OVERFLOW=10
```

### For Large Deployments (1000+ users)
- Use load balancer (HAProxy, AWS ELB)
- Database replication with read replicas
- Redis caching layer
- CDN for static assets
- Container orchestration (Kubernetes)

---

## 🔍 Troubleshooting

### Services won't start
```bash
# Check Docker
sudo systemctl status docker

# View detailed logs
docker-compose logs

# Rebuild and restart
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Database connection errors
```bash
# Verify PostgreSQL is running
docker-compose ps postgres

# Check database
docker-compose exec postgres psql -U genai_user -d genai_stack -c "SELECT 1"

# Check environment variables
grep DATABASE_URL .env
```

### High memory usage
```bash
# Check resource usage
docker stats

# Restart containers
docker-compose restart

# Check logs for memory leaks
docker-compose logs backend | grep -i "memory\|error"
```

### Disk space issues
```bash
# Check disk space
df -h

# Clean up Docker
docker system prune -a

# Archive and compress old logs
find .backups -mtime +60 -exec gzip {} \;
```

---

## 📞 Support Resources

### Documentation
- [QUICK_DEPLOY.md](QUICK_DEPLOY.md) - Fast setup guide
- [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) - Comprehensive guide

### Useful Commands
```bash
# Emergency: Stop all containers
docker-compose down

# Emergency: Restart everything fresh
docker-compose down -v && docker-compose up -d

# Scale services
docker-compose up -d --scale backend=3

# View resource usage
docker stats

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Common Issues
- **Port already in use**: Change ports in docker-compose.yml
- **Out of disk**: Clean up backups, check log rotation
- **Slow API**: Check database, scale backend workers
- **Frontend not loading**: Check nginx config, clear browser cache

---

## 🎯 Next Steps

1. ✅ Deploy using `./deploy.sh`
2. ✅ Configure SSL certificates for HTTPS
3. ✅ Set up automated backups
4. ✅ Monitor application with `./health-check.sh`
5. ✅ Configure domain and DNS
6. ✅ Set up email alerts for critical issues
7. ✅ Document your deployment (for team)
8. ✅ Plan scaling strategy

---

## 📋 Deployment Checklist

```
Pre-Deployment:
☐ Docker and Docker Compose installed
☐ Domain registered (if using custom domain)
☐ SSL certificates prepared/obtained
☐ Database password changed in .env
☐ API keys configured
☐ Firewall configured

Deployment:
☐ Run ./deploy.sh
☐ Verify all containers running (docker-compose ps)
☐ Test frontend (http://your-server:3000)
☐ Test API (http://your-server:8000/docs)
☐ Run health checks (./health-check.sh)

Post-Deployment:
☐ Configure HTTPS/SSL
☐ Set up backup schedule (./backup.sh setup-cron)
☐ Test backup and restore process
☐ Configure monitoring/alerts
☐ Document configuration for team
☐ Set up log rotation
☐ Schedule regular maintenance
```

---

## 🎓 Learning Resources

### Understanding the Stack
- FastAPI: https://fastapi.tiangolo.com/
- React: https://react.dev/
- PostgreSQL: https://www.postgresql.org/docs/
- Docker: https://docs.docker.com/

### Deployment Concepts
- Docker Compose: https://docs.docker.com/compose/
- Nginx: https://nginx.org/en/docs/
- SSL/TLS: https://letsencrypt.org/

---

**Happy deploying! 🚀**

For questions or issues, refer to the comprehensive guides included in this package.
