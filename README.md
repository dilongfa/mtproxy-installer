# MTProxy: Giải pháp Proxy cho Telegram trên Debian 12

## Giới thiệu về MTProxy

MTProxy là một proxy server chính thức được phát triển bởi Telegram, được thiết kế đặc biệt để giúp người dùng truy cập Telegram trong những khu vực bị chặn hoặc hạn chế mạng. Đây là giải pháp proxy được tối ưu hóa riêng cho giao thức Telegram, mang lại hiệu suất cao và bảo mật tốt.

### Tại sao nên sử dụng MTProxy?

**Ưu điểm nổi bật:**
- **Tối ưu cho Telegram**: Được thiết kế riêng cho giao thức MTProto của Telegram, đảm bảo hiệu suất tốt nhất
- **Bảo mật cao**: Sử dụng mã hóa end-to-end, không lưu trữ dữ liệu người dùng
- **Hiệu suất ổn định**: Ít tiêu tốn tài nguyên server, có thể xử lý nhiều kết nối đồng thời
- **Miễn phí và mã nguồn mở**: Hoàn toàn miễn phí và có thể tự kiểm soát
- **Dễ sử dụng**: Chỉ cần một link để kết nối, không cần cài đặt app bổ sung

**Ứng dụng thực tế:**
- Vượt qua firewall và các hạn chế mạng
- Tăng tốc kết nối Telegram tại một số khu vực
- Tự chủ về proxy server thay vì phụ thuộc bên thứ ba
- Chia sẻ proxy cho nhóm/tổ chức sử dụng

### Vấn đề với MTProxy repository chính thức

Repository MTProxy chính thức của Telegram tại `TelegramMessenger/MTProxy` đã lâu không được cập nhật và gặp nhiều vấn đề khi compile trên các hệ điều hành hiện đại:

- **Lỗi compilation**: Không tương thích với GCC và glibc mới
- **Missing dependencies**: Thiếu các header files cần thiết
- **Port binding issues**: Vấn đề với privileged ports
- **Outdated build system**: Makefile chưa được cập nhật

## Script Cài đặt Tự động

Để giải quyết các vấn đề trên, chúng tôi đã phát triển một script bash tự động hóa việc cài đặt MTProxy với các fix và cải tiến sau:

### Tính năng chính của Script

**1. Multi-source Fallback:**
- Thử community fork được maintain tốt hơn trước
- Fallback về original repository với các fix tương thích

**2. Compatibility Fixes:**
- Loại bỏ flag `-Werror` gây lỗi compilation
- Thêm flag `-fcommon` cho GCC mới
- Tự động patch missing headers
- Xử lý vấn đề privileged ports

**3. Security & Best Practices:**
- Tạo user riêng `mtproxy` (non-root)
- Sử dụng systemd để quản lý service
- Cấu hình log rotation tự động
- Setup firewall cơ bản

**4. Management Tools:**
- Script cập nhật cấu hình tự động
- Systemd service với auto-restart
- Log monitoring và debugging tools

## Hướng dẫn Cài đặt

### Yêu cầu Hệ thống

- **Hệ điều hành**: Debian 12 (Bookworm)
- **RAM**: Tối thiểu 512MB (khuyến nghị 1GB+)
- **CPU**: 1 core (khuyến nghị 2+ cores)
- **Disk**: 1GB trống
- **Network**: Public IP với port 443/8443 mở

### Bước 1: Chuẩn bị Hệ thống

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Kiểm tra version Debian
cat /etc/os-release

# Đảm bảo có sudo privileges
sudo whoami
```

### Bước 2: Download và Chạy Script

```bash
# Tải script (thay YOUR_SCRIPT_URL bằng URL thực tế)
wget -O install_mtproxy.sh YOUR_SCRIPT_URL

# Hoặc tạo file và copy nội dung script vào
nano install_mtproxy.sh

# Cấp quyền thực thi
chmod +x install_mtproxy.sh

# Chạy script
./install_mtproxy.sh
```

### Bước 3: Theo dõi Quá trình Cài đặt

Script sẽ thực hiện các bước sau:

1. **Kiểm tra hệ thống** và permissions
2. **Cài đặt dependencies** cần thiết
3. **Tạo user mtproxy** riêng biệt
4. **Download và compile** MTProxy từ source
5. **Cấu hình systemd service**
6. **Setup firewall** và security
7. **Khởi động service** và hiển thị thông tin

### Bước 4: Xác nhận Cài đặt Thành công

```bash
# Kiểm tra service status
sudo systemctl status mtproxy

# Xem logs
sudo journalctl -u mtproxy -f

# Test kết nối
curl -I http://localhost:8888
```

## Cấu hình và Sử dụng

### Thông tin Proxy

Sau khi cài đặt thành công, bạn sẽ nhận được:

```
• Server: YOUR_SERVER_IP
• Port: 443 (hoặc 8443)
• Secret: [32-character hex string]
• Telegram Link: https://t.me/proxy?server=...
```

### Cách Sử dụng Proxy

**Trên Telegram Desktop/Mobile:**
1. Click vào link proxy được cung cấp
2. Telegram sẽ tự động mở và hỏi xác nhận
3. Chọn "Connect" để sử dụng proxy

**Cấu hình thủ công:**
1. Vào Settings → Data and Storage → Proxy Settings
2. Add Proxy → MTProto
3. Nhập Server, Port, và Secret
4. Save và Connect

### Quản lý Service

```bash
# Khởi động
sudo systemctl start mtproxy

# Dừng
sudo systemctl stop mtproxy

# Khởi động lại
sudo systemctl restart mtproxy

# Tự động khởi động cùng hệ thống
sudo systemctl enable mtproxy

# Xem trạng thái
sudo systemctl status mtproxy

# Xem logs realtime
sudo journalctl -u mtproxy -f
```

### Cập nhật Cấu hình

```bash
# Cập nhật proxy config từ Telegram
sudo mtproxy-update

# Tự động cập nhật (thêm vào crontab)
echo "0 2 * * * root /usr/local/bin/mtproxy-update" | sudo tee -a /etc/crontab
```

## Xử lý Sự cố

### Lỗi Compilation

**Vấn đề**: Build failed với lỗi compilation
**Giải pháp**:
```bash
# Thử build với minimal flags
cd /tmp/MTProxy
make clean
make CC=gcc CFLAGS="-O2 -fcommon -w -fPIC"
```

### Lỗi Permission Denied

**Vấn đề**: `bind(): Permission denied`
**Giải pháp**:
```bash
# Cấp quyền bind privileged ports
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/mtproto-proxy

# Hoặc sử dụng port cao hơn
sudo sed -i 's/-H 443/-H 8443/g' /etc/systemd/system/mtproxy.service
sudo systemctl daemon-reload
sudo systemctl restart mtproxy
```

### Service Không Khởi động

**Kiểm tra logs**:
```bash
sudo journalctl -u mtproxy --no-pager
sudo systemctl status mtproxy -l
```

**Các nguyên nhân thường gặp**:
- Port đã được sử dụng: `sudo netstat -tlnp | grep :443`
- File cấu hình lỗi: `sudo ls -la /etc/mtproxy/`
- Binary không tồn tại: `ls -la /usr/local/bin/mtproto-proxy`

### Firewall Issues

```bash
# Kiểm tra firewall status
sudo ufw status

# Mở ports cần thiết
sudo ufw allow 443/tcp
sudo ufw allow 8443/tcp

# Với iptables
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

## Giải pháp Thay thế

Nếu script không hoạt động trên hệ thống của bạn:

### 1. Docker Version (Khuyến nghị)

```bash
# Cài đặt Docker
sudo apt install docker.io -y
sudo systemctl enable docker

# Chạy MTProxy container
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 443:443 \
  -p 8888:8888 \
  telegrammessenger/proxy:latest
```

### 2. Alternative Script

```bash
# Sử dụng script khác đã được test
bash <(curl -s https://raw.githubusercontent.com/HirbodBehnam/MTProtoProxyInstaller/master/MTProtoProxyInstall.sh)
```

### 3. Manual Installation

Tham khảo hướng dẫn chi tiết tại repository community hoặc documentation chính thức.

## Bảo mật và Tối ưu

### Security Best Practices

1. **Thay đổi secret định kỳ**:
```bash
NEW_SECRET=$(head -c 16 /dev/urandom | xxd -ps)
sudo sed -i "s/SECRET=.*/SECRET=$NEW_SECRET/" /etc/mtproxy/config
sudo systemctl restart mtproxy
```

2. **Giới hạn kết nối**:
```bash
# Thêm rate limiting với iptables
sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
```

3. **Monitor logs**:
```bash
# Setup log monitoring
sudo logwatch --service mtproxy --range today --detail high
```

### Performance Tuning

```bash
# Tăng file descriptor limits
echo "mtproxy soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "mtproxy hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo "net.core.somaxconn = 1024" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Kết luận

MTProxy là giải pháp proxy mạnh mẽ và ổn định cho Telegram. Với script cài đặt tự động này, bạn có thể dễ dàng triển khai MTProxy trên Debian 12 mà không gặp phải các vấn đề compilation thường thấy.

**Lưu ý quan trọng:**
- Thường xuyên cập nhật cấu hình proxy
- Monitor logs để phát hiện sớm các vấn đề
- Backup cấu hình và secret key
- Tuân thủ quy định pháp luật địa phương về proxy/VPN

Chúc bạn sử dụng thành công MTProxy!

---

**Liên hệ hỗ trợ**: Nếu gặp vấn đề trong quá trình cài đặt, hãy kiểm tra logs và tham khảo phần xử lý sự cố ở trên.
