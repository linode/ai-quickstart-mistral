set -e

# Function to send ntfy notification
notify() {
    local message="$1"
    curl -s -d "$message" "https://ntfy.sh/$(hostname)" || true
}

notify "☁️ cloud-init package install finished"
sleep 2

# Install NVIDIA drivers
notify "🎮 Installing NVIDIA drivers...(this may takes 2 - 3 minutes)"
ubuntu-drivers autoinstall

# Install Docker
notify "🐳 Installing Docker & Compose..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Add NVIDIA Container Toolkit repository
notify "📦 Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update and install NVIDIA Container Toolkit
apt-get update
apt-get install -y nvidia-container-toolkit

# Configure Docker for NVIDIA
nvidia-ctk runtime configure --runtime=docker

# Restart Docker to apply NVIDIA runtime configuration
systemctl restart docker

# Create systemd service for AI LLM Basic Stack
notify "⚙️ Registering systemd service for AI LLM Basic Stack..."
cat > /etc/systemd/system/ai-llm-basic.service << "EOF"
[Unit]
Description=Start AI LLM Basic Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/ai-llm-basic
ExecStart=/usr/bin/docker compose --progress quiet up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable service (will start containers on boot)
systemctl daemon-reload
systemctl enable ai-llm-basic.service

# Pull latest Docker images
notify "⬇️ Pulling latest vLLM & OpenWebUI container images... (this may take 2 - 3 min)..."
cd /opt/ai-llm-basic
docker compose pull --quiet || true

# Check if NVIDIA modules exist for current kernel
CURRENT_KERNEL=$(uname -r)
if [ -f "/lib/modules/${CURRENT_KERNEL}/kernel/nvidia-580-open/nvidia.ko" ] || \
   [ -f "/lib/modules/${CURRENT_KERNEL}/updates/dkms/nvidia.ko" ]; then
    # Modules exist, load them and start containers now
    notify "🔧 Loading NVIDIA kernel modules..."
    modprobe nvidia 2>/dev/null || true
    modprobe nvidia-uvm 2>/dev/null || true
    modprobe nvidia-modeset 2>/dev/null || true

    # Verify driver is loaded
    if nvidia-smi > /dev/null 2>&1; then
        # Start AI LLM Basic Stack
        cd /opt/ai-llm-basic
        notify "🚀 Starting vLLM & OpenWebUI with docker comopose up ..."
        docker compose up -d
        exit 0
    fi
fi

notify "🔄 Rebooting to load NVIDIA drivers... 🚀 vLLM & OpenWebUI setup will start after reboot"
reboot