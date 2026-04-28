# Production Deployment Files Index

This directory contains everything needed to deploy GenAI-Stack to a production server.

## 📚 Quick Navigation

### For First-Time Setup
1. Start here: [QUICK_DEPLOY.md](QUICK_DEPLOY.md) - 5 minute setup guide
2. Run: `chmod +x setup-env.sh && ./setup-env.sh` - Interactive environment setup
3. Deploy: `chmod +x deploy.sh && ./deploy.sh` - Automated deployment

### For Comprehensive Information
- [README_DEPLOYMENT.md](README_DEPLOYMENT.md) - Complete overview and checklist
- [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) - Detailed deployment guide

---

## 📋 Available Scripts

### Main Deployment
| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy.sh` | One-command deployment | `./deploy.sh` |
| `setup-env.sh` | Environment configuration | `./setup-env.sh` |

### Operations & Maintenance
| Script | Purpose | Usage |
|--------|---------|-------|
| `backup.sh` | Backup & restore | `./backup.sh backup` |
| `health-check.sh` | Monitor application | `./health-check.sh` |
| `install-systemd.sh` | Non-Docker installation | `./install-systemd.sh` |

---

## 🐳 Docker Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Complete service orchestration |
| `backend/Dockerfile` | Backend container image |
| `frontend/Dockerfile.prod` | Frontend production image |
| `nginx.conf` | Reverse proxy configuration |
| `frontend/nginx.conf` | Frontend Nginx config |

---

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `.env.example` | Environment template (copy to .env) |
| `main.tf` | Terraform infrastructure (GCP) |

---

## 📖 Documentation

| Document | Content |
|----------|---------|
| [QUICK_DEPLOY.md](QUICK_DEPLOY.md) | Fast setup (5 min) |
| [README_DEPLOYMENT.md](README_DEPLOYMENT.md) | Overview & checklist |
| [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) | Complete guide |

---

## 🚀 Deployment Steps

### Step 1: Choose Your Path

**Path A: Automated Deployment (Recommended)**
```bash
chmod +x deploy.sh setup-env.sh
./setup-env.sh auto
./deploy.sh
```

**Path B: Interactive Setup**
```bash
chmod +x deploy.sh setup-env.sh health-check.sh
./setup-env.sh          # Interactive menu
./deploy.sh             # Deploy
./health-check.sh       # Verify
```

**Path C: Manual Deployment**
See [QUICK_DEPLOY.md](QUICK_DEPLOY.md) for manual steps

### Step 2: Configure Environment
- Copy `.env.example` to `.env`
- Update with your API keys and settings
- Run `./setup-env.sh` to validate

### Step 3: Deploy
```bash
./deploy.sh
```

### Step 4: Verify
```bash
./health-check.sh all
```

---

## 📊 Service Status

After deployment, access:
- **Frontend**: http://your-server:3000
- **Backend API**: http://your-server:8000
- **API Documentation**: http://your-server:8000/docs

---

## 🔐 Essential Settings

### Before Production
```bash
# 1. Update .env
nano .env
# Change: DB_PASSWORD, GOOGLE_API_KEY, SERPAPI_API_KEY

# 2. Set HTTPS
# Place certificates in ssl/ directory

# 3. Configure domain
# Update REACT_APP_API_URL in .env

# 4. Security
# sudo ufw allow 80,443,22/tcp
```

---

## 📈 Common Operations

### Start/Stop
```bash
docker-compose up -d      # Start
docker-compose stop       # Stop
docker-compose restart    # Restart
```

### Backup
```bash
./backup.sh backup        # Create backup
./backup.sh list          # List backups
./backup.sh restore <file> # Restore
```

### Monitor
```bash
./health-check.sh         # Full check
./health-check.sh continuous # Monitor
docker-compose logs -f    # View logs
```

### Database
```bash
# Access database
docker-compose exec postgres psql -U genai_user -d genai_stack

# Backup
docker-compose exec postgres pg_dump -U genai_user genai_stack > db.sql

# Restore
docker-compose exec -T postgres psql -U genai_user genai_stack < db.sql
```

---

## 🆘 Troubleshooting

### Services won't start
```bash
./health-check.sh        # Check what's wrong
docker-compose logs      # View detailed logs
docker-compose build --no-cache
docker-compose up -d
```

### Port conflicts
Edit `docker-compose.yml` and change port mappings

### Out of disk space
```bash
docker system prune -a   # Clean unused images
./backup.sh cleanup      # Remove old backups
```

### API not responding
```bash
./health-check.sh api    # Check API specifically
docker-compose logs backend
```

---

## 🔄 Deployment Workflow

```
1. Prepare Server
   ↓
2. Run setup-env.sh
   ↓
3. Configure .env
   ↓
4. Run deploy.sh
   ↓
5. Verify with health-check.sh
   ↓
6. Configure SSL/Domain
   ↓
7. Setup Backups (./backup.sh setup-cron)
   ↓
8. Monitor (./health-check.sh continuous)
```

---

## 📞 Getting Help

### Check Logs
```bash
docker-compose logs <service>  # Docker setup
journalctl -u genai-backend -f # Systemd setup
```

### Run Health Checks
```bash
./health-check.sh all          # Full diagnostic
./health-check.sh continuous   # Monitor
```

### Check Specific Services
```bash
./health-check.sh docker       # Docker status
./health-check.sh database     # Database
./health-check.sh api          # API
./health-check.sh frontend     # Frontend
```

---

## 📚 Additional Resources

- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Nginx Configuration](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [React Documentation](https://react.dev/)

---

## 📋 Deployment Checklist

```
☐ Server prepared with Docker/Docker Compose
☐ Environment variables configured (.env)
☐ SSL certificates ready
☐ API keys obtained (Google, SerpAPI)
☐ Database password changed
☐ Deploy script executed
☐ Health checks passed
☐ Domain configured
☐ HTTPS working
☐ Backups automated
☐ Monitoring set up
☐ Firewall configured
```

---

## 🎯 Next Steps After Deployment

1. **Configure HTTPS** - Install SSL certificates
2. **Setup Backups** - `./backup.sh setup-cron`
3. **Monitor Health** - `./health-check.sh continuous`
4. **Configure Domain** - Point DNS to your server
5. **Document Setup** - Create runbook for your team
6. **Plan Scaling** - Consider load balancing for growth

---

## 📞 Support Commands

```bash
# Quick diagnostics
./health-check.sh all

# View all logs
docker-compose logs

# Check resource usage
docker stats

# Test connectivity
curl http://localhost:8000/docs
curl http://localhost:3000

# Database status
docker-compose exec postgres psql -U genai_user -d genai_stack -c "SELECT 1"
```

---

**Start with [QUICK_DEPLOY.md](QUICK_DEPLOY.md) for a 5-minute setup!** 🚀
