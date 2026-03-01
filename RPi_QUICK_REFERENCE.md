# PriceGhost RPi Quick Reference

## TL;DR - Quick Start

```bash
# On Raspberry Pi 4 (64-bit Raspberry Pi OS)
cd ~/priceghost

# Run the automated deployment script
bash deploy-rpi.sh
# Answer prompts for Ollama IP, model, and password
```

That's it! The script handles everything.

---

## Architecture Overview

```
Raspberry Pi 4 (4GB)          |    Powerful Server
                              |
PriceGhost Frontend (8089)     |    Ollama (11434)
    ↓                         |        ↑
PriceGhost Backend (3001) ─────────────┘
    ↓
PostgreSQL Database
```

### What Each Component Does

- **Frontend**: Web UI for tracking products (runs in browser)
- **Backend**: Handles scraping, price voting, scheduling
- **PostgreSQL**: Stores products, prices, users
- **Ollama**: Remote LLM for AI-based price extraction

---

## Quick Setup (Manual Steps)

### 1. Install Docker on Pi
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo apt install -y python3-pip
sudo pip3 install docker-compose
```

### 2. Configure Ollama Server
On your powerful server:
```bash
# Make Ollama accessible from network
OLLAMA_HOST=0.0.0.0:11434 ollama serve

# In another terminal, pull a model
ollama pull mistral  # or: neural-chat, qwen2
```

### 3. Clone and Deploy on Pi
```bash
cd ~
git clone https://github.com/clucraft/priceghost.git
cd priceghost

# Use the automated script OR:

# Manual setup:
cp .env.example .env
# Edit .env with your database password and Ollama IP

docker-compose -f docker-compose.rpi.yml up -d --build
```

### 4. Access Web UI
- Open browser: `http://YOUR_PI_IP:8089`
- Create account
- Go to Settings → AI Settings → Select Ollama provider
- Enter Ollama Base URL: `http://YOUR_SERVER_IP:11434`
- Select model you pulled
- Enable AI toggle
- Save!

---

## Common Commands

### Logs & Monitoring
```bash
# View all logs
docker-compose -f docker-compose.rpi.yml logs -f

# View specific service
docker-compose -f docker-compose.rpi.yml logs -f backend

# Real-time resource usage
docker stats

# Check service status
docker-compose -f docker-compose.rpi.yml ps
```

### Start/Stop Services
```bash
# Start
docker-compose -f docker-compose.rpi.yml up -d

# Stop (keeps data)
docker-compose -f docker-compose.rpi.yml stop

# Restart
docker-compose -f docker-compose.rpi.yml restart backend

# Complete shutdown (deletes everything!)
docker-compose -f docker-compose.rpi.yml down -v
```

### Database Access
```bash
# Connect to PostgreSQL directly
docker exec -it priceghost-db psql -U postgres -d priceghost

# Inside psql:
\dt                          # List tables
SELECT * FROM users;         # View users
SELECT * FROM products;      # View tracked products
\q                           # Exit
```

### Troubleshooting
```bash
# Is Ollama reachable?
curl http://YOUR_SERVER_IP:11434/api/tags

# Check Ollama is listening
netstat -tuln | grep 11434  # on your server

# Pi resource usage
free -h                      # Memory
df -h                        # Disk space
vcgencmd measure_temp        # CPU temperature

# Rebuild containers
docker-compose -f docker-compose.rpi.yml build --no-cache

# Clean up unused images/containers
docker system prune -a
```

---

## Configuration Files

### `.env` - Main Configuration
```bash
POSTGRES_PASSWORD=your_password
OLLAMA_BASE_URL=http://192.168.1.100:11434  # Your server IP
```

### `docker-compose.rpi.yml` - Service Configuration
- Defines backend, frontend, database services
- Sets memory limits for Pi
- Maps ports (8089, 3001, 5432)

### `backend/Dockerfile.rpi` - Backend Build
- ARM64 optimized
- Alpine Linux base image (lightweight)
- Configures Puppeteer for scraping

### `frontend/Dockerfile.rpi` - Frontend Build
- ARM64 optimized Nginx
- Serves static frontend files

---

## Performance Tips

1. **Use wired Ethernet**: More stable than WiFi
2. **Keep refresh intervals reasonable**: 2-4 hours is good for RPi
3. **Monitor temperature**: `vcgencmd measure_temp` should stay <80°C
4. **Use lightweight Ollama models**: `orca-mini` (3B) or `neural-chat` (7B)
5. **Check disk space**: `df -h` (need at least 5GB free)
6. **Disable AI verification if slow**: Only use initial extraction

---

## Backup & Restore

### Backup Database
```bash
docker exec priceghost-db pg_dump -U postgres priceghost > backup.sql
```

### Restore Database
```bash
docker exec -i priceghost-db psql -U postgres priceghost < backup.sql
```

### Backup Everything
```bash
docker-compose -f docker-compose.rpi.yml down
tar -czf priceghost_backup.tar.gz postgres_data/ .env
docker-compose -f docker-compose.rpi.yml up -d
```

---

## Network Setup

### Find Your Pi's IP
```bash
hostname -I
```

### Find Your Server's IP
On your powerful server:
```bash
hostname -I
# Use the local network IP (usually 192.168.x.x)
```

### Test Network Connectivity
```bash
# From Pi, ping server:
ping 192.168.1.100

# Test Ollama port:
telnet 192.168.1.100 11434
```

---

## Recommended Ollama Models

| Model | Size | Speed | Quality | Notes |
|-------|------|-------|---------|-------|
| orca-mini | 3GB | ⚡⚡⚡ | ⭐⭐ | Fast, okay accuracy |
| neural-chat | 4GB | ⚡⚡ | ⭐⭐⭐ | Good balance |
| mistral | 5GB | ⚡⚡ | ⭐⭐⭐⭐ | Best general purpose |
| qwen2 | 5GB | ⚡⚡ | ⭐⭐⭐⭐ | Great for structured tasks |
| dolphin-mixtral | 26GB | ⚡ | ⭐⭐⭐⭐⭐ | Best quality (needs powerful server) |

```bash
# Pull a model
ollama pull mistral

# List all local models
ollama list
```

---

## Supported Refresh Intervals

Set in PriceGhost UI when adding products:

| Interval | Good For | RPi Impact |
|----------|----------|-----------|
| 30 min | Emergency tracking | ⚠️ Heavy load |
| 1 hour | Active sales | Medium load |
| 2-4 hours | Normal tracking | ✅ Recommended |
| 6-12 hours | Long-term monitoring | Light load |
| 24 hours | Passive monitoring | ✅ Best for RPi |

---

## Upgrade PriceGhost

```bash
cd ~/priceghost

# Get latest code
git pull

# Rebuild with new code
docker-compose -f docker-compose.rpi.yml up -d --build
```

Data is preserved in PostgreSQL volume!

---

## Disable AI Features (if slow)

In Web UI → Settings → AI Settings:

- **Disable AI Extraction**: Uses only 3 other methods (JSON-LD, CSS, Site-Specific)
- **Disable AI Verification**: Skips the second AI pass

This reduces Ollama calls significantly.

---

## System Requirements

### Minimal
- Raspberry Pi 3B+
- 2GB RAM
- 16GB microSD (Class 10+)
- 5V 2.5A power supply

### Recommended (for RPi 4)
- Raspberry Pi 4
- 4GB RAM (or 8GB)
- 32GB microSD (U3, Class A2 recommended)
- 5V 3A power supply w/ USB-C
- Wired Ethernet preferred

---

## Getting Help

### Check Logs
```bash
docker-compose -f docker-compose.rpi.yml logs backend
```

### Access Database
```bash
docker exec -it priceghost-db psql -U postgres -d priceghost
```

### Full Documentation
See: [DEPLOY_TO_RASPBERRY_PI.md](DEPLOY_TO_RASPBERRY_PI.md)

### GitHub Issues
[github.com/clucraft/priceghost/issues](https://github.com/clucraft/priceghost)

---

## Environment Variables Reference

Create in `.env`:

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secure_password_here

# Backend
JWT_SECRET=random_jwt_secret_here
PORT=3001

# Remote Ollama (IMPORTANT!)
OLLAMA_BASE_URL=http://192.168.1.100:11434
OLLAMA_MODEL=mistral

# Frontend
VITE_API_URL=/api

# Optional: Node.js memory limit
NODE_OPTIONS=--max-old-space-size=1536
```

---

## Success Indicators

✅ Everything working when:
- Web UI loads at `http://YOUR_PI_IP:8089`
- Login works
- Can add a product URL
- Price extraction shows results
- No 502 errors in browser
- Logs show no errors: `docker-compose -f docker-compose.rpi.yml logs backend`

⚠️ Watch for:
- Out of memory errors → reduce refresh frequency
- Ollama timeout errors → verify network connectivity
- Slow extractions → use lighter Ollama model
- database connection refused → wait for PostgreSQL to start

---

## Emergency Stop

If something goes wrong:

```bash
# Stop all services immediately
docker-compose -f docker-compose.rpi.yml kill

# Verify they're stopped
docker-compose -f docker-compose.rpi.yml ps

# Clean restart
docker-compose -f docker-compose.rpi.yml down
docker-compose -f docker-compose.rpi.yml up -d
```

Your data is safe in the PostgreSQL volume!

---

Last updated: March 2026
