# Technical Implementation Plan: One-Click AI Sandbox

**Status:** Draft v1.0  
**Focus:** Technical architecture, implementation details, and technology stack

---

## 1. Technology Stack

### Base Operating System
- **OS:** Ubuntu 22.04 LTS (Minimal)
- **Rationale:** Stable, well-supported LTS release with broad compatibility

### Container Runtime & Orchestration
- **Docker Engine:** Latest stable version
- **Docker Compose:** Version 2
- **Rationale:** Industry-standard containerization for isolated, reproducible deployments

### GPU Support
- **NVIDIA Drivers:** Latest stable version compatible with Linode's kernel
- **GPU Access:** Full GPU passthrough to containers via Docker GPU support
- **Rationale:** Required for high-performance AI model inference

### Deployment Platform
- **Marketplace:** Linode Marketplace App
- **Deployment Mechanism:** Linode StackScript (executes on first boot)
- **Base Image:** Custom private image ("Golden Image") pre-configured with all dependencies

---

## 2. System Architecture

### High-Level Architecture
```
┌─────────────────────────────────────────┐
│         Linode GPU Instance             │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │     StackScript (First Boot)     │  │
│  │  - Reads MODEL_ID from UDF       │  │
│  │  - Creates directories           │  │
│  │  - Generates docker-compose.yml  │  │
│  │  - Launches services             │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │    Docker Compose Services       │  │
│  │                                   │  │
│  │  ┌──────────────┐  ┌──────────┐ │  │
│  │  │  API Service │  │ UI Service│ │  │
│  │  │  (vLLM)     │  │(Open WebUI)│ │  │
│  │  │  Port: 8000 │  │ Port: 3000│ │  │
│  │  └──────────────┘  └──────────┘ │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │    Persistent Storage             │  │
│  │  - /opt/models (model cache)     │  │
│  │  - /opt/open-webui (UI data)     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Service Architecture

#### Service 1: API (AI Inference Engine)
- **Container Image:** `ghcr.io/vllm-project/vllm-openai:latest`
- **Purpose:** High-performance AI model inference with OpenAI-compatible API
- **Port Mapping:** Host `8000` → Container `8000`
- **GPU Access:** Full GPU access (`gpus: all`)
- **Volume Mounts:**
  - Host `/opt/models` → Container model cache directory
- **Environment Variables:**
  - `MODEL_ID`: Passed from User-Configurable Field (UDF)
- **Restart Policy:** `unless-stopped`
- **API Endpoint:** `http://<instance-ip>:8000/v1`

#### Service 2: UI (Chat Interface)
- **Container Image:** `ghcr.io/open-webui/open-webui:main`
- **Purpose:** Browser-based chat interface for interacting with AI models
- **Port Mapping:** Host `3000` → Container `8080`
- **Volume Mounts:**
  - Host `/opt/open-webui` → Container data directory (persistent chat history)
- **Environment Variables:**
  - `OPENAI_API_BASE_URL`: `http://api:8000/v1` (internal Docker network)
- **Dependencies:** `depends_on: [api]` (waits for API service to be ready)
- **Restart Policy:** `unless-stopped`
- **Web Interface:** `http://<instance-ip>:3000`

---

## 3. Deployment Implementation

### Linode StackScript Logic

The StackScript executes the following sequence on first boot:

1. **Read Configuration:**
   - Extract `MODEL_ID` from User-Configurable Field (UDF) variable

2. **Create Directory Structure:**
   ```bash
   /opt/models          # Model cache directory
   /opt/open-webui      # UI persistent data
   /opt/ai-sandbox      # Docker Compose configuration location
   ```

3. **Generate Docker Compose Configuration:**
   - Write `docker-compose.yml` to `/opt/ai-sandbox/docker-compose.yml`
   - Template includes:
     - Service definitions for `api` and `ui`
     - Volume mounts
     - Environment variables (including `MODEL_ID`)
     - Network configuration
     - GPU configuration
     - Restart policies

4. **Launch Services:**
   - Execute: `docker-compose -f /opt/ai-sandbox/docker-compose.yml up -d`
   - Services start in background with automatic restart on failure

5. **Post-Deployment:**
   - Write security warning and getting started instructions to `/etc/motd`
   - Message visible on SSH login

### Docker Compose Configuration Structure

```yaml
version: '3.8'
services:
  api:
    image: ghcr.io/vllm-project/vllm-openai:latest
    ports:
      - "8000:8000"
    volumes:
      - /opt/models:/models
    environment:
      - MODEL_ID=${MODEL_ID}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped

  ui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    volumes:
      - /opt/open-webui:/app/backend/data
    environment:
      - OPENAI_API_BASE_URL=http://api:8000/v1
    depends_on:
      - api
    restart: unless-stopped
```

---

## 4. File System Structure

### Host Directories
```
/opt/
├── models/              # Model cache (persistent across restarts)
├── open-webui/          # UI data and chat history (persistent)
└── ai-sandbox/
    └── docker-compose.yml   # Service configuration
```

### System Files
```
/etc/motd                # Message of the Day (security warnings, getting started)
```

---

## 5. Networking & Ports

### Exposed Ports
- **Port 8000:** API service (OpenAI-compatible REST API)
- **Port 3000:** Web UI (browser-based chat interface)

### Network Configuration
- **Default Binding:** `0.0.0.0` (all interfaces, internet-accessible)
- **Internal Communication:** Services communicate via Docker internal network using service names (`api`, `ui`)
- **Security:** No built-in authentication; relies on Linode Cloud Firewall for access control

---

## 6. User Configuration (UDF)

### User-Configurable Field
- **Field Label:** "Model ID"
- **Variable Name:** `MODEL_ID`
- **Type:** Text input
- **Help Text:** "Enter any model ID from Hugging Face (e.g., `meta-llama/Llama-3-8B-Instruct`)."
- **Default Value:** `mistralai/Mistral-7B-Instruct-v0.3`
- **Validation:** User-provided; no server-side validation (relies on container image handling)

---

## 7. Base Image ("Golden Image") Requirements

### Pre-Installed Components
1. **Ubuntu 22.04 LTS (Minimal)**
   - Base operating system
   - Minimal footprint for faster boot times

2. **NVIDIA Drivers**
   - Latest stable version
   - Compatible with Linode's kernel
   - Pre-configured for GPU access

3. **Docker Engine**
   - Latest stable release
   - Configured to start on boot
   - GPU support enabled

4. **Docker Compose v2**
   - Installed and available in PATH
   - Required for service orchestration

### Image Optimization
- **Purpose:** Reduce first-boot time by pre-installing dependencies
- **Maintenance:** Image must be updated when dependencies require updates
- **Distribution:** Private custom image (not publicly available)

---

## 8. Non-Functional Requirements

### Performance
- **Time-to-Value:** Services must be live and responsive within 5 minutes of instance reaching "Running" state
- **Boot Time:** Optimized through pre-configured base image
- **Model Loading:** First model load may take additional time depending on model size and network speed

### Security
- **Default Exposure:** Services bound to `0.0.0.0` (internet-accessible)
- **Authentication:** None by default (V1)
- **Access Control:** Users must configure Linode Cloud Firewall
- **Security Warning:** Displayed in `/etc/motd` on SSH login
- **Ports to Protect:** 3000 (UI) and 8000 (API)

### Maintainability
- **Service Updates:** Users can update by editing `/opt/ai-sandbox/docker-compose.yml` and running `docker-compose up -d`
- **Configuration Management:** All configuration in single `docker-compose.yml` file
- **Logging:** Standard Docker logging via `docker-compose logs`
- **Persistence:** Data persists in `/opt/models` and `/opt/open-webui` across container restarts

### Reliability
- **Restart Policy:** `unless-stopped` for both services
- **Service Dependencies:** UI waits for API to be ready
- **Error Handling:** Container failures trigger automatic restart

---

## 9. Technical Constraints

### Platform Constraints
- **Deployment Target:** Linode/Akamai Cloud GPU instances only
- **Instance Types:** Must support all relevant GPU instance types
- **Kernel Compatibility:** NVIDIA drivers must be compatible with Linode's kernel

### Resource Constraints
- **GPU:** Requires GPU instance (no CPU-only support)
- **Memory:** Model-dependent (user must select appropriate instance size)
- **Storage:** Model cache requires sufficient disk space for selected model

### Version Constraints
- **Docker Compose:** Must use v2 (not legacy v1)
- **Container Images:** Uses `latest`/`main` tags (no version pinning in V1)

---

## 10. Out of Scope (V1 Technical Limitations)

### Not Implemented
- **Authentication:** No API keys, tokens, or user accounts
- **HTTPS/SSL:** No automatic certificate management or reverse proxy
- **Load Balancing:** Single instance deployment only
- **High Availability:** No multi-instance or failover support
- **Monitoring:** No built-in health checks or metrics collection
- **Backup:** No automated backup of model cache or UI data
- **Fine-tuning:** Inference-only; no training capabilities
- **Multi-model:** Single model per instance (configured at deployment)

---

## 11. Future Technical Considerations

### Potential Enhancements (Post-V1)
- Version pinning for container images
- Health check endpoints
- Built-in monitoring and logging aggregation
- Automated backup solutions
- Reverse proxy with SSL termination
- API authentication mechanisms
- Support for multiple models per instance
- Horizontal scaling capabilities

