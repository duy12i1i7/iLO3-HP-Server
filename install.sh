#!/bin/bash

# ==============================================================================
# TỰ ĐỘNG CÀI ĐẶT ILO 3 PROXY TRÊN RASPBERRY PI
# ==============================================================================

# 1. BIẾN MÔI TRƯỜNG
# (Thay đổi các giá trị này nếu hệ thống mạng của bạn khác biệt)
ILO_IP="192.168.100.2"
PROXY_IP="192.168.100.7"
DOCKER_IMAGE_NAME="ilo-nginx-legacy"
CONTAINER_NAME="ilo-proxy"
SSL_DIR="/opt/ilo-proxy/ssl"
CONF_DIR="/opt/ilo-proxy/conf"
NGINX_CONF_SRC="./nginx-ilo.conf"
SOCAT_SERVICE_SRC="./socat-ilo@.service"

echo "Bắt đầu cài đặt iLO 3 Proxy..."

# 2. KIỂM TRA QUYỀN ROOT
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script với quyền root (sudo ./install.sh)"
  exit 1
fi

# 3. CHUẨN BỊ THƯ MỤC
echo "[1/6] Đang chuẩn bị thư mục cấu hình..."
mkdir -p "$SSL_DIR"
mkdir -p "$CONF_DIR"

# Cập nhật địa chỉ IP thực tế vào file cấu hình (nếu có thay đổi)
sed "s/192.168.100.2/$ILO_IP/g" "$NGINX_CONF_SRC" | sed "s/192.168.100.7/$PROXY_IP/g" > "$CONF_DIR/nginx-ilo.conf"

# 4. TẠO CHỨNG CHỈ SSL TỰ KÝ (CHO ỨNG DỤNG STANDALONE)
echo "[2/6] Đang tạo chứng chỉ SSL giả (Self-Signed) cho Nginx..."
if [ ! -f "$SSL_DIR/nginx.crt" ]; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$SSL_DIR/nginx.key" -out "$SSL_DIR/nginx.crt" \
        -subj "/CN=ilo-proxy" > /dev/null 2>&1
    echo "  -> Đã tạo chứng chỉ SSL mới."
else
    echo "  -> Chứng chỉ SSL đã tồn tại."
fi

# 5. CÀI ĐẶT DOCKER (NẾU CHƯA CÓ)
echo "[3/6] Kiểm tra Docker..."
if ! command -v docker &> /dev/null; then
    echo "  -> Không tìm thấy Docker. Đang cài đặt Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    # Cấu hình Registry Mirror cho Docker (để vượt lỗi Rate Limit)
    mkdir -p /etc/docker
    echo "{\"registry-mirrors\": [\"https://mirror.gcr.io\"]}" > /etc/docker/daemon.json
    systemctl restart docker
else
    echo "  -> Docker đã được cài đặt."
fi

# 6. BUILD VÀ CHẠY DOCKER NGINX
echo "[4/6] Đang Build và chạy Nginx 16.04 Container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Build từ Dockerfile hiện tại
docker build -t "$DOCKER_IMAGE_NAME" .

# Chạy container
docker run -d --restart always \
    --name "$CONTAINER_NAME" \
    -p 80:80 \
    -p 443:443 \
    -p 8443:8443 \
    -v "$CONF_DIR/nginx-ilo.conf:/etc/nginx/nginx.conf:ro" \
    -v "$SSL_DIR:/etc/nginx/ssl:ro" \
    "$DOCKER_IMAGE_NAME"
echo "  -> Nginx container đã khởi chạy (Cổng 80, 443, 8443)."

# 7. CÀI ĐẶT SOCAT VÀ SYSTEMD SERVICES
echo "[5/6] Đang cài đặt Socat (Pure TCP Proxy) cho Video/Bàn phím..."
apt-get update > /dev/null 2>&1
apt-get install -y socat > /dev/null 2>&1

# Copy file template service vào systemd
cp "$SOCAT_SERVICE_SRC" /etc/systemd/system/

# Khởi động dịch vụ trên 3 cổng KVM của iLO
systemctl daemon-reload

echo "  -> Đang khởi chạy Socat Proxy trên các cổng 17988, 17990, 27910..."
systemctl enable --now socat-ilo@17988.service
systemctl enable --now socat-ilo@17990.service
systemctl enable --now socat-ilo@27910.service

# Khởi động lại phòng trường hợp đã chạy trước đó
systemctl restart socat-ilo@17988.service
systemctl restart socat-ilo@17990.service
systemctl restart socat-ilo@27910.service

# 8. HOÀN TẤT
echo "[6/6] HOÀN TẤT!"
echo "=============================================================================="
echo "Bạn có thể sử dụng iLO 3 thông qua địa chỉ của máy Proxy: $PROXY_IP"
echo "- Trình duyệt Web: http://$PROXY_IP"
echo "- Phần mềm iLO IRC Standalone: Nhập $PROXY_IP vào ô Address."
echo "=============================================================================="
