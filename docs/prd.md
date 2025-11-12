# PRD: Marketplace App - "One-Click AI Sandbox" (v1.0)

- **Status:** Draft v1.0
- **Product:** Akamai Cloud / Linode Marketplace
- **Goal:** Provide the fastest-possible "time-to-joy" for any user on Akamai GPU instances by deploying a complete, pre-configured AI chat UI and a compatible API endpoint with one click.

---

## 1. Problem & Opportunity

**The Problem:**
Developers and AI-curious users face significant friction when trying to run open-source models. They must provision a GPU instance, then spend hours installing complex NVIDIA drivers, Docker, ML-ops tooling, and inference servers. To get a chat UI, they must then find, install, and configure a separate web application to talk to the API.

**The Solution (The "App"):**
A "One-Click" Marketplace App that deploys a complete, containerized "AI Sandbox." When the user provisions a GPU instance, this app will automatically install and configure *both* a high-performance, OpenAI-compatible API and a feature-rich, browser-based chat UI.

A user can boot the instance and, within 3-5 minutes, be chatting with their own private AI model in a browser *and* have a stable API endpoint to integrate into their applications.

---

## 2. User Personas & User Stories

* **Persona 1: The AI Explorer:** "As a non-developer, I want to try the latest open-source models (like Llama 3) in a chat interface, so that I can see what they are capable of without writing any code or paying for a per-token API."
* **Persona 2: The Backend Engineer:** "As a backend engineer, I want a stable, OpenAI-compatible API, so that I can point my existing application to my own endpoint just by changing the `BASE_URL`."
* **Persona 3: The Full-Stack Developer:** "As a developer, I want to use the chat UI to experiment with prompts, and then use the *same* underlying API in my application, so I can ensure consistent results."

---

## 3. V1 Functional Requirements

### R1: Marketplace Deployment
* The solution **shall** be delivered as a **Linode Marketplace App**.
* The app **shall** be deployable on all relevant Akamai/Linode GPU instance types.

### R2: Base Image (The "Golden Image")
* The Marketplace App **shall** deploy on a **private Custom Image** (the "Golden Image") to ensure fast boot times and stability.
* This image **shall** come pre-installed and pre-configured with:
    1.  Ubuntu 22.04 LTS (Minimal)
    2.  NVIDIA Drivers (latest stable, compatible with Linode's kernel)
    3.  Docker Engine
    4.  **Docker Compose** (v2)

### R3: Deployment Logic (Linode StackScript)
* The core app logic **shall** be executed by a **Linode StackScript** that runs on first boot.
* The StackScript **shall** perform the following actions:
    1.  Read the `MODEL_ID` from the User-Configurable Field (UDF).
    2.  Create a host directory for the model cache (`/opt/models`).
    3.  Create a host directory for the UI data (`/opt/open-webui`).
    4.  Write a `docker-compose.yml` file to `/opt/ai-sandbox/docker-compose.yml`.
    5.  Run `docker-compose -f /opt/ai-sandbox/docker-compose.yml up -d` to launch the entire stack.
    6.  Write a "Getting Started" and security warning message to the system Message of the Day (`/etc/motd`).

### R4: Service Architecture (`docker-compose.yml`)
The StackScript **shall** create a `docker-compose.yml` file that defines two services:

1.  **`api` (The AI Engine):**
    * **Container:** `ghcr.io/vllm-project/vllm-openai:latest`
    * **Port:** Expose host port `8000` to container port `8000`.
    * **Volumes:** Mount the host's `/opt/models` to the container's model cache.
    * **GPU:** Enable `gpus: all`.
    * **Environment:** Pass the `MODEL_ID` from the UDF (e.g., `- MODEL_ID=${MODEL_ID}`).
    * **Restart:** `unless-stopped`.

2.  **`ui` (The Chat Interface):**
    * **Container:** `ghcr.io/open-webui/open-webui:main`
    * **Port:** Expose host port `3000` to container port `8080`.
    * **Volumes:** Mount the host's `/opt/open-webui` for persistent chat history.
    * **Environment:** Configure it to point to the `api` service (e.g., `- OPENAI_API_BASE_URL=http://api:8000/v1`).
    * **Depends On:** `depends_on: [api]`.
    * **Restart:** `unless-stopped`.

### R5: User Configuration (UDF)
* The Marketplace App **shall** provide one **User-Configurable Field (UDF)** at deployment:
    * **Label:** `Model ID`
    * **Variable:** `MODEL_ID`
    * **Help Text:** "Enter any model ID from Hugging Face (e.g., `meta-llama/Llama-3-8B-Instruct`)."
    * **Default Value:** `mistralai/Mistral-7B-Instruct-v0.3`

---

## 4. Non-Functional Requirements (NFRs)

* **Time-to-Value:** From the moment the Linode instance is "Running," both the UI and API endpoints **shall** be live and responsive within **5 minutes**.
* **Security:** Both services will be open to the internet (`0.0.0.0`) by default.
    * **CRITICAL:** The StackScript **shall** write a clear warning to `/etc/motd`, viewable on SSH login, instructing the user to configure a **Linode Cloud Firewall** to protect **both port 3000 (UI) and port 8000 (API)**.
* **Maintainability:** The app's components shall be independently updatable by editing the `docker-compose.yml` file and re-running `docker-compose up -d`.

---

## 5. Out of Scope (For V1)

* **NO** automatic API authentication (user must use firewall).
* **NO** user accounts for the UI (it will be open by default).
* **NO** automatic HTTPS/SSL.
* **NO** support for fine-tuning. This is an **inference** appliance.

---

## 6. Success Metrics

* **Adoption:** # of "One-Click AI Sandbox" deployments in the first 30 days.
* **Activation:** % of deployed instances that serve >1,000 API requests (indicates real use).
* **Utilization:** Increase in overall GPU instance-hours provisioned.
* **Qualitative:** Feedback from developers ("This saved me a whole day of work").