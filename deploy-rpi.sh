#!/bin/bash

###############################################################################
# PriceGhost Raspberry Pi 4 Quick Deploy Script
# This script handles the setup and deployment of PriceGhost on RPi with
# remote Ollama instance
###############################################################################

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     PriceGhost Raspberry Pi 4 Deployment Script                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on ARM64
if [[ ! $(uname -m) =~ ^aarch64 ]]; then
    echo -e "${YELLOW}⚠ Warning: This script is optimized for ARM64 (Raspberry Pi)${NC}"
    echo -e "${YELLOW}Current architecture: $(uname -m)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check Docker installation
echo -e "${BLUE}📦 Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not installed${NC}"
    echo "Install with: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not installed${NC}"
    echo "Install with: sudo pip3 install docker-compose"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed${NC}"

# Check if in PriceGhost directory
if [ ! -f "docker-compose.rpi.yml" ]; then
    echo -e "${RED}✗ docker-compose.rpi.yml not found${NC}"
    echo "Make sure you're in the PriceGhost directory"
    exit 1
fi
echo -e "${GREEN}✓ PriceGhost files found${NC}"
echo ""

# Get Ollama server information
echo -e "${BLUE}🌐 Ollama Configuration${NC}"
read -p "Enter Ollama server IP address (default: 192.168.1.100): " OLLAMA_IP
OLLAMA_IP=${OLLAMA_IP:-192.168.1.100}

read -p "Enter Ollama model name (default: mistral, options: neural-chat, mistral, qwen2): " OLLAMA_MODEL
OLLAMA_MODEL=${OLLAMA_MODEL:-mistral}

echo "Testing Ollama connection to $OLLAMA_IP:11434..."
if timeout 5 curl -s "http://$OLLAMA_IP:11434/api/tags" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama server is reachable${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not reach Ollama server${NC}"
    echo "Make sure Ollama is running on $OLLAMA_IP and port 11434 is open"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Generate JWT secret if needed
echo -e "${BLUE}🔐 Security Configuration${NC}"
if [ -f ".env" ] && grep -q "JWT_SECRET=" ".env" && [ ! -z "$(grep '^JWT_SECRET=' .env | cut -d'=' -f2)" ]; then
    echo -e "${GREEN}✓ JWT_SECRET already configured${NC}"
    EXISTING_JWT=$(grep '^JWT_SECRET=' .env | cut -d'=' -f2)
else
    echo "Generating new JWT_SECRET..."
    JWT_SECRET=$(openssl rand -base64 32)
    echo -e "${GREEN}✓ JWT_SECRET generated${NC}"
fi

# Get database password
read -s -p "Enter PostgreSQL password (or press Enter to generate random): " DB_PASSWORD
echo
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    echo -e "${GREEN}✓ Generated password: $DB_PASSWORD${NC}"
fi
echo ""

# Create .env file
echo -e "${BLUE}📝 Creating .env file...${NC}"
cat > .env << EOF
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=priceghost

# Backend
JWT_SECRET=${JWT_SECRET:-$EXISTING_JWT}

# Frontend
VITE_API_URL=/api

# Remote Ollama Configuration
OLLAMA_BASE_URL=http://$OLLAMA_IP:11434
OLLAMA_MODEL=$OLLAMA_MODEL
EOF

echo -e "${GREEN}✓ .env file created${NC}"
echo ""

# Build and start services
echo -e "${BLUE}🚀 Building and starting services...${NC}"
echo "This may take 15-30 minutes on first run (downloading images, building)..."
echo ""

docker-compose -f docker-compose.rpi.yml down 2>/dev/null || true
docker-compose -f docker-compose.rpi.yml up -d --build

# Wait for services to be ready
echo ""
echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker-compose -f docker-compose.rpi.yml ps | grep -E "priceghost-(backend|frontend|db)" | grep -q "Up"; then
        READY_SERVICES=$(docker-compose -f docker-compose.rpi.yml ps | grep -E "priceghost-(backend|frontend|db)" | grep "Up" | wc -l)
        if [ $READY_SERVICES -eq 3 ]; then
            echo -e "${GREEN}✓ All services are running${NC}"
            break
        fi
    fi
    ATTEMPT=$((ATTEMPT+1))
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${YELLOW}⚠ Services taking longer than expected. Check logs with:${NC}"
    echo "docker-compose -f docker-compose.rpi.yml logs -f"
fi

echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
docker-compose -f docker-compose.rpi.yml ps
echo ""

# Get PI IP
PI_IP=$(hostname -I | awk '{print $1}')

echo "╔════════════════════════════════════════════════════════════════╗"
echo -e "${GREEN}✓ PriceGhost deployment complete!${NC}"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}📱 Access PriceGhost:${NC}"
echo "Browser: http://$PI_IP:8089"
echo ""
echo -e "${BLUE}⚙ Backend API:${NC}"
echo "URL: http://$PI_IP:3001"
echo ""
echo -e "${BLUE}🗄 Database:${NC}"
echo "Host: localhost"
echo "Port: 5432"
echo "User: postgres"
echo "Password: $DB_PASSWORD"
echo ""
echo -e "${BLUE}📚 Useful Commands:${NC}"
echo "View logs:     docker-compose -f docker-compose.rpi.yml logs -f"
echo "Stop:          docker-compose -f docker-compose.rpi.yml stop"
echo "Start:         docker-compose -f docker-compose.rpi.yml up -d"
echo "Restart:       docker-compose -f docker-compose.rpi.yml restart"
echo "Stats:         docker stats"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Open http://$PI_IP:8089 in your browser"
echo "2. Create an account or login"
echo "3. Go to Settings > AI Settings"
echo "4. Select 'Ollama' as provider"
echo "5. Verify Base URL is: http://$OLLAMA_IP:11434"
echo "6. Start adding products to track!"
echo ""
echo -e "${YELLOW}💾 Don't forget to save your password:${NC}"
echo "PostgreSQL: $DB_PASSWORD"
echo "JWT Secret: ${JWT_SECRET:-[already in .env]}"
echo ""
