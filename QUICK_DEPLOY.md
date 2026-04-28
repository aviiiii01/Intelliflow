# Quick Production Deployment Guide

## 🚀 Quick Start (5 minutes)

### Prerequisites
- Linux server (Ubuntu/Debian recommended)
- Docker & Docker Compose installed
- Domain name (optional, for HTTPS)

### Step 1: Clone and Setup

```bash
# Copy your project to the server
scp -r /path/to/GenAI-Stack user@your-server:/opt/

# SSH into your server
ssh user@your-server

# Navigate to project
cd /opt/GenAI-Stack

# Make deployment script executable
chmod +x deploy.sh
```

### Step 2: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your API keys
nano .env
# Update:
# - DB_PASSWORD (change the password!)
# - GOOGLE_API_KEY
# - SERPAPI_API_KEY
# - REACT_APP_API_URL (for production)
```

### Step 3: Deploy

```bash
# Run the deployment script
./deploy.sh
```

This will:
- ✅ Check prerequisites
- ✅ Setup environment
- ✅ Build Docker images
- ✅ Start all services (PostgreSQL, ChromaDB, Backend, Frontend)
- ✅ Initialize database
- ✅ Run health checks

### Step 4: Access Your Application

```
Frontend:  http://your-server:3000
API Docs:  http://your-server:8000/docs
```

---

## 📋 Manual Deployment (if you prefer)

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your configuration

# 2. Create required directories
mkdir -p backend/uploaded_files backend/chroma_db_gemini ssl

# 3. Generate SSL certificates (self-signed)
openssl req -x509 -newkey rsa:4096 -nodes \
    -out ssl/cert.pem -keyout ssl/key.pem \
    -days 365 -subj "/CN=localhost"

# 4. Start all services
docker-compose up -d

# 5. Check status
docker-compose ps

# 6. View logs
docker-compose logs -f
```

---

## 🔐 HTTPS Setup (Production)

### Option A: Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-dns-route53  # or your DNS provider

# Get certificate
sudo certbot certonly --dns-route53 -d your-domain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
sudo chown $(whoami) ssl/cert.pem ssl/key.pem

# Restart containers
docker-compose restart nginx
```

### Option B: Use Your Own Certificates

```bash
# Copy your certificate and key
cp /path/to/your/cert.pem ssl/cert.pem
cp /path/to/your/key.pem ssl/key.pem

# Restart services
docker-compose restart nginx
```

---

## 📊 Monitor Your Application

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres

# Check resource usage
docker stats

# Check service health
docker-compose ps
```

---

## 🛠️ Common Commands

```bash
# Stop services
docker-compose stop

# Start services
docker-compose start

# Restart services
docker-compose restart

# Rebuild containers
docker-compose build --no-cache

# Remove everything and start fresh
docker-compose down -v
docker-compose up -d

# Database backup
docker-compose exec postgres pg_dump -U genai_user genai_stack > backup.sql

# Database restore
docker-compose exec -T postgres psql -U genai_user genai_stack < backup.sql

# Scale backend instances (if using load balancer)
docker-compose up -d --scale backend=3
```

---

## 🔧 Troubleshooting

### Services won't start
```bash
# Check Docker daemon
sudo systemctl status docker

# Check logs for errors
docker-compose logs

# Rebuild containers
docker-compose build --no-cache
docker-compose up -d
```

### Database connection error
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Verify environment variables
grep DATABASE_URL .env
```

### Frontend not loading
```bash
# Check if frontend container is running
docker-compose ps frontend

# Check frontend logs
docker-compose logs frontend

# Verify Nginx configuration
docker exec genai_nginx nginx -t
```

### API not responding
```bash
# Check backend status
docker-compose ps backend

# Check backend logs
docker-compose logs backend

# Test API endpoint
curl http://localhost:8000/docs
```

---

## 📈 Performance Optimization

### Increase Backend Workers
Edit `backend/Dockerfile`:
```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### Enable Database Connection Pooling
Edit `.env`:
```
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=10
```

### Configure Nginx Caching
Already configured in `nginx.conf` with:
- Static asset caching (1 year)
- Gzip compression
- Rate limiting

---

## 🔐 Security Checklist

- [ ] Changed `DB_PASSWORD` in `.env`
- [ ] Set `DEBUG=false` in `.env`
- [ ] Configured HTTPS certificates
- [ ] Restricted firewall (ports 80, 443, 22 only)
- [ ] Set up automated backups
- [ ] Configured rate limiting
- [ ] Restricted CORS origins in production
- [ ] Regular security updates

---

## 📞 Support

For issues or questions:

1. Check logs: `docker-compose logs`
2. Review [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)
3. Check Docker container status: `docker-compose ps`
4. Verify all environment variables: `cat .env`

---

## 🚀 Advanced Deployment

For high-traffic production environments, see [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for:
- Load balancing
- Database replication
- CDN integration
- Kubernetes deployment
- Auto-scaling configuration

