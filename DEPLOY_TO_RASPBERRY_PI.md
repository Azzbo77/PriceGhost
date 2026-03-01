# PriceGhost on Raspberry Pi 4 with Remote Ollama

## Overview

This guide walks you through deploying PriceGhost on a Raspberry Pi 4 (4GB) while connecting to an Ollama instance running on a more powerful server.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Your Raspberry Pi 4 (4GB RAM)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────┐     ┌──────────────────────────┐  │
│  │   Frontend               │     │   Backend API            │  │
│  │   (Nginx)                │     │   (Node.js)              │  │
│  │   Browser UI             │────▶│   Price Scraping         │  │
│  │   8089                   │     │   Price Voting           │  │
│  │                          │     │   3001                   │  │
│  └──────────────────────────┘     └──────────┬───────────────┘  │
│                                               │                  │
│  ┌──────────────────────────┐                │                  │
│  │   PostgreSQL             │                │                  │
│  │   (Database)             │◀───────────────┘                  │
│  │                          │                                   │
│  └──────────────────────────┘                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
         ▲
         │ HTTP Request (Ollama API calls)
         │ 192.168.1.100:11434
         │
┌─────────────────────────────────────────────────────────────────┐
│ Your Powerful Server (Desktop/NAS/Server)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────┐                                   │
│  │   Ollama                 │                                   │
│  │   LLM Models             │                                   │
│  │   (mistral, neural-chat) │                                   │
│  │   :11434                 │                                   │
│  │                          │                                   │
│  └──────────────────────────┘                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### On Raspberry Pi 4
- **OS**: Raspberry Pi OS (Lite or Desktop - 64-bit recommended)
- **Memory**: 4GB RAM (minimum 2GB, but 4GB provides better performance)
- **Storage**: 16GB+ microSD card (32GB+ recommended)
- **Docker**: Docker and Docker Compose installed
- **Network**: Stable network connection to your server

### On Your Powerful Server
- **Ollama**: Running and accessible from your Pi's network
- **Models**: At least one model downloaded (e.g., `mistral`, `neural-chat`)
- **Open Port**: 11434 (Ollama's default port)

## Step 1: Set Up Raspberry Pi OS

### 1.1 Flash Raspberry Pi OS

Use Raspberry Pi Imager to flash your microSD card:

```bash
# Option 1: Use official Raspberry Pi Imager (GUI)
# https://www.raspberrypi.com/software/

# Option 2: Command line
sudo apt install rpi-imager
rpi-imager
```

**Recommendations:**
- Use **64-bit OS** for better performance
- Use **Lite version** if you only need headless operation (saves ~1GB disk space)

### 1.2 Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.3 Expand Filesystem (if needed)

```bash
sudo raspi-config
# Select: Advanced Options > Expand Filesystem
# Reboot
```

## Step 2: Install Docker on Raspberry Pi

### 2.1 Install Docker using convenient script

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 2.2 Add user to docker group (optional, but recommended)

```bash
sudo usermod -aG docker $USER
# Log out and log back in for this to take effect
```

### 2.3 Install Docker Compose

```bash
sudo apt install -y python3-pip
sudo pip3 install docker-compose
# Or use official method:
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Verify installation:

```bash
docker --version
docker-compose --version
```

## Step 3: Configure Ollama on Your Server

### 3.1 Install Ollama on powerful server

If not already installed:

```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### 3.2 Make Ollama accessible from network

By default, Ollama only listens on localhost. Modify the systemd service:

```bash
# Edit Ollama service
sudo systemctl edit ollama

# Add or modify the ExecStart line to include network binding:
# [Service]
# ExecStart=/usr/bin/ollama serve

# To bind to all network interfaces, set environment variable:
# Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Or run Ollama with network access directly:

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

### 3.3 Pull a suitable model for price extraction

Recommended lightweight models that work well on powerful servers:

```bash
# Option 1: Mistral (7B, ~5GB) - Excellent performance/speed
ollama pull mistral

# Option 2: Neural Chat (7B, ~4GB) - Good for price extraction
ollama pull neural-chat

# Option 3: Orca Mini (3B, ~2GB) - Faster but less accurate
ollama pull orca-mini

# Option 4: Qwen2 (7B, ~5GB) - Great at structured tasks
ollama pull qwen2
```

### 3.4 Test Ollama connectivity from Pi

SSH into your Pi and test:

```bash
# Replace 192.168.1.100 with your server's actual IP
curl http://192.168.1.100:11434/api/tags
```

This should return a list of available models.

## Step 4: Clone and Configure PriceGhost on Raspberry Pi

### 4.1 Clone the repository

```bash
cd ~
git clone https://github.com/clucraft/priceghost.git
cd priceghost
```

### 4.2 Set up environment file

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```bash
nano .env
```

Ensure these are set:

```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=YourSecurePasswordHere  # Change this!
POSTGRES_DB=priceghost

JWT_SECRET=$(openssl rand -base64 32)  # Generate strong secret

# For frontend API calls
VITE_API_URL=/api
```

### 4.3 Create a .env file for remote Ollama configuration

Create or edit `.env.ollama`:

```bash
cat > .env.ollama << 'EOF'
# Replace 192.168.1.100 with your server's IP address
OLLAMA_BASE_URL=http://192.168.1.100:11434

# Default model to use for price extraction
# Must match a model you've pulled on Ollama (e.g., mistral, neural-chat, qwen2)
OLLAMA_MODEL=mistral
EOF
```

## Step 5: Deploy PriceGhost on Raspberry Pi

### 5.1 Build and start services using the RPi-optimized compose file

```bash
# Pull source to get the latest Dockerfiles
git pull

# Build and start (this will take 10-20 minutes on first run)
docker-compose -f docker-compose.rpi.yml up -d
```

The `-d` flag runs services in the background.

### 5.2 Monitor container builds and startup

```bash
# View build progress and logs
docker-compose -f docker-compose.rpi.yml logs -f

# Wait for "priceghost-backend | listening on port 3001" message
# Then press Ctrl+C to exit logs
```

### 5.3 Verify services are running

```bash
docker-compose -f docker-compose.rpi.yml ps
```

Should show:
- `priceghost-db` (healthy)
- `priceghost-backend` (up)
- `priceghost-frontend` (up)

## Step 6: Configure PriceGhost to Use Remote Ollama

### 6.1 Access PriceGhost

Open your browser and go to:

```
http://YOUR_PI_IP:8089
```

(Replace `YOUR_PI_IP` with your Raspberry Pi's IP address)

### 6.2 Register and log in

Create an account or log in if enabled.

### 6.3 Configure Ollama settings

1. **Go to Settings** (gear icon or profile menu)
2. **Navigate to AI Settings**
3. **Select AI Provider: Ollama**
4. **Enter Ollama Configuration:**
   - **Ollama Base URL**: `http://192.168.1.100:11434` (use your server's IP)
   - **Model**: `mistral` (or whichever you pulled)
5. **Enable AI** toggle
6. **Save Settings**

### 6.4 Test the integration

1. Add a test product
2. PriceGhost will use the 4 extraction methods (JSON-LD, Site-Specific, Generic CSS, AI)
3. You should see AI extraction results if configured correctly

## Step 7: Optimize Performance

### 7.1 Monitor resource usage

```bash
# In one terminal, watch real-time stats
docker stats

# In another terminal, check individual container logs
docker-compose -f docker-compose.rpi.yml logs backend
docker-compose -f docker-compose.rpi.yml logs postgres
```

### 7.2 Tune refresh intervals

In the web UI, adjust product refresh intervals:
- **Frequent updates** (every 30 min): Use when expecting price drops
- **Normal** (every 2-4 hours): Recommended for RPi to preserve resources
- **Infrequent** (every 24 hours): When you just want monitoring

### 7.3 Disable AI verification if bandwidth is tight

If your network is slow:
1. Go to Settings > AI Settings
2. Disable "AI Verification" toggle
3. This disables the second AI pass but keeps initial extraction

### 7.4 Use lightweight Ollama models

If you're noticing slow Ollama responses:

```bash
# On your server, try smaller models:
ollama pull orca-mini      # 3B model - fast
ollama pull neural-chat    # 7B model - balanced
ollama pull qwen2-0.5b     # 0.5B model - very fast but less capable
```

Then update the model in PriceGhost settings.

## Step 8: Enable Auto-start and Persistence

### 8.1 Ensure containers restart after reboot

The compose file already has `restart: unless-stopped`, so services will auto-start.

Verify:

```bash
docker-compose -f docker-compose.rpi.yml config | grep -A2 "restart_policy"
```

### 8.2 Create a convenient startup script

```bash
cat > ~/start-priceghost.sh << 'EOF'
#!/bin/bash
cd ~/priceghost
docker-compose -f docker-compose.rpi.yml up -d
echo "PriceGhost started. Access at http://$(hostname -I | awk '{print $1}'):8089"
EOF

chmod +x ~/start-priceghost.sh
```

Use it:

```bash
~/start-priceghost.sh
```

### 8.3 Create a stop script

```bash
cat > ~/stop-priceghost.sh << 'EOF'
#!/bin/bash
cd ~/priceghost
docker-compose -f docker-compose.rpi.yml down
echo "PriceGhost stopped"
EOF

chmod +x ~/stop-priceghost.sh
```

## Troubleshooting

### Backend won't start

```bash
# Check backend logs
docker-compose -f docker-compose.rpi.yml logs backend

# Common issues:
# 1. Database not ready - wait 30 seconds and restart backend
# 2. Port 3001 already in use - change port in compose file
# 3. Out of memory - reduce refresh frequency or disable AI verification
```

### Can't reach Ollama from Pi

```bash
# Test from Pi's terminal:
curl http://192.168.1.100:11434/api/tags

# If fails:
# 1. Check server's firewall allows port 11434
# 2. Verify correct IP address
# 3. Verify Ollama is running: systemctl status ollama (on server)
# 4. Check OLLAMA_HOST is set to 0.0.0.0:11434 on server
```

### Database keeps crashing

```bash
# Check postgres logs
docker-compose -f docker-compose.rpi.yml logs postgres

# If out of memory:
# 1. Stop containers: docker-compose -f docker-compose.rpi.yml down
# 2. Reduce refresh intervals in the app
# 3. Increase swap space on Pi (optional)
```

### Slow price extraction

```bash
# Check if Ollama is responding quickly
curl http://192.168.1.100:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "What is 2+2?",
  "stream": false
}'

# If slow:
# 1. Use faster model (orca-mini or neural-chat)
# 2. Check server isn't under heavy load
# 3. Disable AI verification temporarily
# 4. Increase OLLAMA_Base_URL timeout
```

### Web UI not accessible

```bash
# Check if frontend is running
docker-compose -f docker-compose.rpi.yml ls frontend

# Check Pi's IP address
hostname -I

# Try accessing via:
http://YOUR_PI_IP:8089

# Or try localhost if on the same machine:
http://localhost:8089
```

## Useful Commands

### View all running containers

```bash
docker-compose -f docker-compose.rpi.yml ps
```

### View logs in real-time

```bash
docker-compose -f docker-compose.rpi.yml logs -f backend  # Backend logs
docker-compose -f docker-compose.rpi.yml logs -f postgres # Database logs
docker-compose -f docker-compose.rpi.yml logs -f frontend # Frontend logs
```

### Stop services without deleting data

```bash
docker-compose -f docker-compose.rpi.yml stop
```

### Completely remove services and volumes (wipes database!)

```bash
docker-compose -f docker-compose.rpi.yml down -v
```

### Restart a specific service

```bash
docker-compose -f docker-compose.rpi.yml restart backend
```

### Access database directly

```bash
docker exec -it priceghost-db psql -U postgres -d priceghost

# In psql:
\dt  # List tables
SELECT * FROM users;  # Query users
\q   # Exit
```

## Performance Tips for Raspberry Pi 4 (4GB)

1. **Use 64-bit OS**: Better memory management and performance
2. **Enable zram swap**: Adds compressed RAM swap
3. **Disable desktop/GUI if headless**: Saves ~500MB RAM
4. **Use fast microSD card**: U3 class minimum, Class A2 recommended
5. **Keep network close**: Wired ethernet better than WiFi
6. **Monitor temperature**: `vcgencmd measure_temp` should be <80°C
7. **Avoid overlocking**: Keep clock speed default for stability
8. **Regular backups**: Back up `postgres_data` volume regularly

## Backing Up Your Data

### Backup the database

```bash
docker exec priceghost-db pg_dump -U postgres priceghost > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Backup everything including database volume

```bash
docker-compose -f docker-compose.rpi.yml down
tar -czf priceghost_backup_$(date +%Y%m%d).tar.gz postgres_data/
docker-compose -f docker-compose.rpi.yml up -d
```

## Next Steps

1. **Add products**: Test price tracking with some URLs
2. **Enable notifications**: Set up Telegram, Discord, or other alerts
3. **Customize refresh intervals**: Based on your tracking needs
4. **Monitor performance**: Use `docker stats` to ensure Pi isn't overloaded

## Support

For issues specific to PriceGhost, check:
- GitHub Issues: https://github.com/clucraft/priceghost
- Ollama Documentation: https://github.com/ollama/ollama

For Raspberry Pi issues:
- Official Docs: https://www.raspberrypi.com/documentation/
