# Ollama Remote Connection Troubleshooting

This guide helps you verify that your Raspberry Pi can successfully communicate with your remote Ollama instance.

## Quick Diagnostics

Run these commands from your Raspberry Pi to diagnose connection issues:

### 1. Verify Ollama Server is Running (on your server)

```bash
# On your powerful server:
systemctl status ollama

# Or if running manually:
ps aux | grep ollama
```

Expected output: Service is active/running

### 2. Check Network Connectivity from Pi to Server

```bash
# From Pi, test basic connectivity:
ping YOUR_SERVER_IP
# Should get responses with ~1-50ms latency

# Test port connection:
telnet YOUR_SERVER_IP 11434
# Should connect (Ctrl+C to exit)

# Or using curl (better):
curl -v http://YOUR_SERVER_IP:11434/api/tags
# Should return JSON with model list
```

### 3. Verify Ollama Listens on 0.0.0.0

On your powerful server, check Ollama binding:

```bash
# Check what Ollama is listening on:
netstat -tuln | grep 11434
# Should show: 0.0.0.0:11434 or :::11434

# If only showing 127.0.0.1, fix it:
sudo systemctl edit ollama

# Add this section (or modify existing):
# [Service]
# Environment="OLLAMA_HOST=0.0.0.0:11434"

# Then restart:
sudo systemctl restart ollama
```

### 4. Test Model Availability

```bash
# From Pi:
curl http://YOUR_SERVER_IP:11434/api/tags

# Should return something like:
# {
#   "models": [
#     {
#       "name": "mistral:latest",
#       ...
#     }
#   ]
# }
```

If models list is empty, pull a model on your server:

```bash
# On your server:
ollama pull mistral
# or
ollama pull neural-chat
```

### 5. Test AI Generation

```bash
# From Pi, test actual generation:
curl http://YOUR_SERVER_IP:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "What is 2+2?",
  "stream": false
}'

# Should return a response within 5-30 seconds
# Response time depends on model size and server power
```

Watch for:
- **Timeout**: Ollama server is too slow, use a lighter model
- **Connection refused**: Port/firewall issue
- **Empty response**: Model not properly loaded

---

## Common Issues & Solutions

### Issue: "Connection refused" or "Cannot reach server"

**Symptoms:**
- `curl` shows "Connection refused"
- Backend logs show Ollama timeout errors

**Diagnosis:**
```bash
# 1. Check Ollama is running on server:
systemctl status ollama

# 2. Check port is listening:
netstat -tuln | grep 11434

# 3. Check firewall isn't blocking:
sudo ufw status  # on your server
sudo ufw allow 11434  # if needed

# 4. Verify you're using correct IP:
hostname -I  # on server - use first IP
```

**Solution:**
1. Ensure Ollama is running: `ollama serve` or `systemctl start ollama`
2. Ensure it's listening on 0.0.0.0: `OLLAMA_HOST=0.0.0.0:11434 ollama serve`
3. Open firewall if needed
4. Verify correct IP address in Pi's `.env`

---

### Issue: "No models available" or "Model not found"

**Symptoms:**
- `curl http://IP:11434/api/tags` returns empty list
- PriceGhost settings show no models available

**Diagnosis:**
```bash
# On your server, list local models:
ollama list

# Should show like: mistral (6.7B) 42MB
```

**Solution:**
```bash
# On your server, pull a model:
ollama pull mistral
# Wait for download to complete...
ollama list  # Verify it's there

# Then restart PriceGhost backend:
docker-compose -f docker-compose.rpi.yml restart backend
```

---

### Issue: Very Slow Responses (30+ seconds per extraction)

**Symptoms:**
- Each product extraction takes 30-60+ seconds
- Server CPU is maxed out

**Diagnosis:**
```bash
# On your server, watch system load:
watch -n 1 free -h
watch -n 1 top

# Check which model you're using is demanding:
ollama list
```

**Solutions (in order of effectiveness):**

1. **Use a lighter model** (fastest fix):
   ```bash
   ollama pull orca-mini      # 3B - fastest
   ollama pull neural-chat    # 7B - balanced
   ollama pull mistral        # 7B - good quality
   ```
   Then update PriceGhost settings to use the lighter model

2. **Upgrade server hardware**: If optimal model still slow

3. **Reduce refresh frequency**: In PriceGhost UI, set longer intervals (4+ hours)

4. **Disable AI verification**: Settings → AI Settings → Turn off "AI Verification"
   - Uses only initial extraction, skips re-check

---

### Issue: Intermittent Connection Failures

**Symptoms:**
- Sometimes works, sometimes fails
- Random "Connection timeout" errors in logs
- Network appears unstable

**Diagnosis:**
```bash
# From Pi, test multiple times:
for i in {1..10}; do
  echo "Test $i:"
  curl -w "HTTP %{http_code}, Time: %{time_total}s\n" \
    http://YOUR_SERVER_IP:11434/api/tags
  sleep 1
done

# Check network stability:
ping -c 20 YOUR_SERVER_IP  # Check for packet loss
```

**Solutions:**

1. **Use wired Ethernet instead of WiFi**:
   - WiFi has more latency/dropout
   - Wired is more reliable

2. **Check network cables and switch**:
   - Loose connections cause dropouts
   - Try different cables/ports

3. **Increase timeout in backend** (if implementing custom retry):
   - Current setting is 120s for Ollama requests
   - May need to increase if network is slow

4. **Check for network congestion**:
   - Use `iftop` or `nethogs` to see traffic
   - Too much traffic can cause timeouts

---

### Issue: Memory/Resource Errors on Server

**Symptoms:**
- Server becomes very slow or freezes
- "out of memory" errors
- Ollama stops responding

**Solutions:**

1. **Close other applications** on server to free RAM

2. **Use smaller model**:
   ```bash
   ollama pull orca-mini  # Uses ~3GB RAM
   ollama pull neural-chat  # Uses ~4GB RAM
   ```

3. **Reduce concurrent requests**:
   - In PriceGhost, lower product refresh frequency
   - Prevents multiple simultaneous Ollama requests

4. **Upgrade server RAM**: If consistently running out of memory

---

### Issue: Database Shows Extraction Errors but Web UI Seems OK

**Symptoms:**
- Web UI works
- Some products show "Unknown price"
- Backend logs show extraction failures

**Check:**
```bash
# View backend logs:
docker-compose -f docker-compose.rpi.yml logs backend -f

# Look for lines like:
# "Error: No response from Ollama"
# "Connection refused"
# "Timeout"
```

**Solutions based on error type:**

- **"No response from Ollama"**: Ollama not reachable
  - Run connectivity tests above

- **"Timeout"**: Ollama taking too long
  - Use faster model or disable AI verification

- **"JSON parse error"**: Ollama returned unexpected format
  - Usually means model crashed, restart Ollama:
    ```bash
    systemctl restart ollama  # on server
    ```

---

## Performance Tuning

### For fast responses (under 5 seconds per extraction):

1. Use lightweight model: `ollama pull orca-mini`
2. Use fast server: 16GB+ RAM, modern CPU
3. Use wired network: Ethernet vs WiFi
4. Lower refresh intervals: 4-6 hours (fewer concurrent requests)

### For quality responses (accepts 10-30 seconds):

1. Use balanced model: `ollama pull neural-chat` or `mistral`
2. Regular server: 8GB+ RAM, decent CPU
3. Any network: WiFi OK, latency <100ms
4. Normal refresh: 2-4 hours

### For maximum quality (accepts 30+ seconds):

1. Use powerful model: `ollama pull dolphin-mixtral` (26GB!)
2. Powerful server: 32GB+ RAM, high-end CPU
3. Wired network recommended
4. Sparse refresh: 12-24 hours (few concurrent requests)

---

## Verification Checklist

Use this before declaring setup complete:

- [ ] `curl http://YOUR_IP:11434/api/tags` works from Pi
- [ ] Returns list of at least one model
- [ ] Can generate response: `curl http://YOUR_IP:11434/api/generate -d '{"model":"mistral","prompt":"hi","stream":false}'`
- [ ] Response comes back in <10 seconds
- [ ] PriceGhost web UI loads at `http://PI_IP:8089`
- [ ] Can login/create account
- [ ] Settings → AI Settings shows Ollama selected
- [ ] Base URL matches your server: `http://YOUR_SERVER_IP:11434`
- [ ] Model name matches what's installed: `mistral`, `neural-chat`, etc.
- [ ] Save settings works without errors
- [ ] Add a product URL
- [ ] Backend logs show AI extraction working
- [ ] Modal appears with price candidates from AI method

If all checked ✓, you're good to go!

---

## Still Having Issues?

### Gather Debug Information

```bash
# 1. PriceGhost backend logs:
docker-compose -f docker-compose.rpi.yml logs backend 2>&1 | tail -50

# 2. Network diagnostics from Pi:
echo "=== Network config ===" && hostname -I && \
echo "=== Ollama reachability ===" && curl -v http://YOUR_SERVER_IP:11434/api/tags 2>&1 | head -20 && \
echo "=== System resources ===" && free -h && df -h /

# 3. Docker status:
docker ps && docker stats --no-stream

# 4. Save to file for analysis:
{
  date
  echo "=== HOSTNAME ===" && hostname
  echo "=== IP ADDRESSES ===" && hostname -I
  echo "=== DOCKER PS ===" && docker ps
  echo "=== BACKEND LOGS ===" && docker-compose -f docker-compose.rpi.yml logs backend | tail -50
  echo "=== OLLAMA TEST ===" && curl -v http://YOUR_SERVER_IP:11434/api/tags 2>&1
  echo "=== SYSTEM ===" && free -h && df -h /
} > priceghost_debug.log

# Share debug.log when asking for help
```

### Get Help

1. Check [DEPLOY_TO_RASPBERRY_PI.md](DEPLOY_TO_RASPBERRY_PI.md) for detailed setup
2. Review relevant sections of [RPi_QUICK_REFERENCE.md](RPi_QUICK_REFERENCE.md)
3. Search GitHub issues: https://github.com/clucraft/priceghost/issues
4. Check Ollama documentation: https://github.com/ollama/ollama

---

## Quick Fix: Start Fresh

If troubleshooting isn't helping, nuke and rebuild:

```bash
# On Raspberry Pi:
cd ~/priceghost

# Stop everything
docker-compose -f docker-compose.rpi.yml down -v  # Warning: deletes database!

# Check connectivity first (verify before rebuild)
curl http://YOUR_SERVER_IP:11434/api/tags

# Rebuild everything
docker-compose -f docker-compose.rpi.yml up -d --build

# Wait a minute for startup
sleep 60

# Check logs
docker-compose -f docker-compose.rpi.yml logs -f
```

This fresh start often resolves issues.

---

Last Updated: March 2026
