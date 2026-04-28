# Production Deployment Guide

This guide covers deploying the GenAI-Stack application to a production server.

## Architecture Overview

- **Frontend**: React application (serves on port 3000)
- **Backend**: FastAPI application (runs on port 8000)
- **Database**: PostgreSQL (required)
- **Vector DB**: ChromaDB (for knowledge base)
- **Infrastructure**: Google Cloud Platform (Terraform configuration provided)

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Docker and Docker Compose installed
- PostgreSQL 12+ installed
- Node.js 18+ and npm
- Python 3.9+
- Domain name (for HTTPS)
- SSL certificates

## Step 1: Set Up Environment Variables

Create a `.env` file in the backend directory:

```bash
# Database
DATABASE_URL=postgresql://username:password@your_db_host:5432/genai_stack

# API Keys
GOOGLE_API_KEY=your_google_api_key
SERPAPI_API_KEY=your_serpapi_api_key

# ChromaDB
CHROMA_HOST=localhost
CHROMA_PORT=8000

# FastAPI
FASTAPI_ENV=production
```

## Step 2: Deploy Backend

### Option A: Using Docker

```bash
cd backend
docker build -t genai-backend:latest .
docker run -d \
  --name genai-backend \
  -p 8000:8000 \
  --env-file .env \
  -v /data/uploaded_files:/app/uploaded_files \
  -v /data/chroma_db:/app/chroma_db_gemini \
  genai-backend:latest
```

### Option B: Using Docker Compose

Create `docker-compose.yml` in the root directory:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: genai_stack
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  chroma:
    image: ghcr.io/chroma-core/chroma:latest
    ports:
      - "8001:8000"
    volumes:
      - chroma_data:/chroma/data

  backend:
    build: ./backend
    depends_on:
      - db
      - chroma
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/genai_stack
      GOOGLE_API_KEY: ${GOOGLE_API_KEY}
      SERPAPI_API_KEY: ${SERPAPI_API_KEY}
      CHROMA_HOST: chroma
      CHROMA_PORT: 8000
    volumes:
      - ./backend/uploaded_files:/app/uploaded_files
      - ./backend/chroma_db_gemini:/app/chroma_db_gemini

  frontend:
    build: ./frontend
    ports:
      - "3000:80"
    depends_on:
      - backend

volumes:
  postgres_data:
  chroma_data:
```

Deploy with:
```bash
docker-compose up -d
```

## Step 3: Deploy Frontend

### Option A: Build and Serve

```bash
cd frontend
npm run build
# Serve with nginx or your preferred web server
```

### Option B: Using Docker

The docker-compose setup includes frontend deployment.

## Step 4: Set Up Nginx as Reverse Proxy

Create `/etc/nginx/sites-available/genai-stack`:

```nginx
upstream backend {
    server 127.0.0.1:8000;
}

upstream frontend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name your-domain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/ssl/certs/your-cert.crt;
    ssl_certificate_key /etc/ssl/private/your-key.key;

    # Frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }

    # Widget
    location /widget.js {
        proxy_pass http://backend/widget.js;
    }

    # Static files
    location /static/ {
        proxy_pass http://backend/static/;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/genai-stack /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 5: Deploy Infrastructure with Terraform (Optional)

If deploying on Google Cloud:

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

## Step 6: Set Up Systemd Services (Alternative to Docker)

Create `/etc/systemd/system/genai-backend.service`:

```ini
[Unit]
Description=GenAI Backend API
After=network.target

[Service]
Type=simple
User=genai
WorkingDirectory=/opt/genai-stack/backend
Environment="PATH=/opt/genai-stack/backend/myenv/bin"
ExecStart=/opt/genai-stack/backend/myenv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable genai-backend
sudo systemctl start genai-backend
```

## Step 7: Database Migrations & Setup

```bash
cd backend
source myenv/bin/activate
python -c "from app.core.db import engine; from app.models.stack import Base; Base.metadata.create_all(bind=engine)"
```

## Step 8: Health Checks & Monitoring

### Health Check Endpoint

Add to your monitoring:
```bash
curl https://your-domain.com/docs  # API documentation
curl https://your-domain.com/health  # If you add a health endpoint
```

### Add Health Endpoint (Optional)

Update [backend/app/main.py](backend/app/main.py#L1):

```python
@app.get("/health")
def health_check():
    return {"status": "healthy"}
```

## Step 9: Enable HTTPS with Let's Encrypt

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot certonly --nginx -d your-domain.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

## Step 10: Backup Strategy

Create a backup script:

```bash
#!/bin/bash
BACKUP_DIR="/backups/genai-stack"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup database
pg_dump $DATABASE_URL > $BACKUP_DIR/db_backup_$TIMESTAMP.sql

# Backup uploaded files
tar -czf $BACKUP_DIR/files_backup_$TIMESTAMP.tar.gz ./backend/uploaded_files

# Keep only last 30 days
find $BACKUP_DIR -mtime +30 -delete
```

Schedule with cron:
```bash
0 2 * * * /opt/genai-stack/backup.sh
```

## Monitoring & Logging

### Docker Logs
```bash
docker-compose logs -f backend
docker-compose logs -f frontend
```

### System Logs
```bash
sudo journalctl -u genai-backend -f
```

## Performance Optimization

1. **Enable CORS properly** - Update in [backend/app/main.py](backend/app/main.py#L1) for specific origins
2. **Add database connection pooling** - Use SQLAlchemy connection pools
3. **Cache static assets** - Configure Nginx caching
4. **Use async workers** - Scale with uvicorn workers
5. **Monitor resource usage** - Set up CPU/memory limits

## Troubleshooting

### Backend connection refused
```bash
# Check if backend is running
docker ps | grep genai-backend

# Check logs
docker logs genai-backend
```

### Database connection failed
```bash
# Verify PostgreSQL is running
sudo systemctl status postgresql

# Check connection
psql -h localhost -U username -d genai_stack
```

### Frontend not loading
```bash
# Check Nginx status
sudo systemctl status nginx

# Verify Nginx config
sudo nginx -t
```

## Production Checklist

- [ ] Environment variables configured
- [ ] PostgreSQL database created and secured
- [ ] ChromaDB running and accessible
- [ ] Backend container/service running
- [ ] Frontend built and served
- [ ] Nginx reverse proxy configured
- [ ] HTTPS/SSL certificates installed
- [ ] Firewall rules configured (allow 443, 80, 22)
- [ ] Database backups automated
- [ ] Monitoring and logging set up
- [ ] CORS origins restricted
- [ ] API rate limiting configured
- [ ] Health checks monitoring
- [ ] Disk space monitoring

## Scale Your Application

For higher traffic:

1. **Use load balancers** - Distribute traffic across multiple backend instances
2. **Database replication** - Set up PostgreSQL replicas
3. **CDN for frontend** - Use CloudFlare or similar
4. **Cache layer** - Add Redis for session/data caching
5. **Container orchestration** - Consider Kubernetes for auto-scaling

---

For support and issues, check the application logs and ensure all environment variables are correctly set.
