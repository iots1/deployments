# 🐳 Deployments

Repository นี้ใช้สำหรับรวบรวม `Dockerfile` และ `docker-compose.yml` ของโปรเจกต์ต่างๆ ที่ใช้ภายในองค์กรหรือเพื่อการทดลองใช้งาน รวมถึง Scripts ที่เกี่ยวข้องกับการ Build และ Deploy ระบบผ่าน Docker

## 📁 โครงสร้างของ Repo

```
deployments/
├── project-1/
│   ├── Dockerfile
│   └── docker-compose.yml
├── project-2/
│   ├── Dockerfile
│   └── docker-compose.yml
├── nginx/
│   └── default.conf
└── README.md
```

## 🚀 วิธีใช้งาน

### 1. Clone Repo

```bash
git clone https://github.com/iots1/deployments.git
cd deployments
```

### 2. เข้าไปยังโฟลเดอร์ของโปรเจกต์ที่ต้องการ

```bash
cd project-1
```

### 3. สร้างและรัน Container

```bash
docker-compose up -d --build
```

หรือถ้าใช้แค่ Dockerfile:

```bash
docker build -t your-image-name .
docker run -d -p 8080:80 your-image-name
```

## 🔧 การตั้งค่า

- คุณสามารถปรับค่าต่างๆ ใน `docker-compose.yml` หรือ `Dockerfile` ตามความต้องการ เช่น:
  - port mapping
  - volume mounting
  - environment variables

## 📝 หมายเหตุ

- โปรเจกต์นี้เหมาะสำหรับ dev/test environment หากต้องการใช้ใน production ควรเพิ่มการจัดการความปลอดภัย และ monitoring
- หากมี secrets ควรใช้ `.env` ไฟล์แยกต่างหาก (และไม่ commit เข้า repo)

## 📦 Tools ที่แนะนำให้ใช้ร่วมกัน

- [Docker](https://www.docker.com/)
- [Portainer](https://www.portainer.io/) — GUI สำหรับจัดการ container
- [Traefik](https://traefik.io/) — Reverse proxy ที่รองรับ Docker labels
- [Watchtower](https://containrrr.dev/watchtower/) — สำหรับ auto-update image

## 👤 ผู้ดูแล

Maintained by [iots1](https://github.com/iots1)

---

## 🔁 Deployment Script (deploy.sh)

สคริปต์ `deploy.sh` นี้ถูกออกแบบมาเพื่อช่วยอัตโนมัติขั้นตอนการ Build, Push Docker Image และ Redeploy ผ่าน Portainer สำหรับทั้ง **Production** (main) และ **Development** (develop) environment

### ✅ ความสามารถหลัก

- ตรวจสอบคำสั่งจำเป็น (`git`, `docker`, `curl`, `jq`, `sed`)
- ตรวจจับ branch (`main` หรือ `develop`) แล้วกำหนดค่าที่เหมาะสม
- อัปเดตเวอร์ชันในไฟล์ `package.json` และตัว script เอง
- Build และ Push Docker image พร้อม tag เช่น `1.0.0` และ `latest`/`develop`
- ล็อกอินเข้า Docker Registry (GitLab)
- ส่งคำสั่ง pull image ไปยัง Portainer API (ถ้ากำหนดให้เปิดใช้งาน)
- Trigger Webhook สำหรับ redeploy service ผ่าน Portainer
- สร้าง git commit และ git tag ให้โดยอัตโนมัติ (เฉพาะ main)

### ⚙️ วิธีใช้

```bash
chmod +x deploy.sh
./deploy.sh
```

ระบบจะถาม input เวอร์ชันใหม่ เช่น `1.0.1` แล้วดำเนินการตามขั้นตอนโดยอัตโนมัติ

### 🔐 ตัวแปรสำคัญที่สามารถ override ได้

- `GITLAB_ACCESS_TOKEN` – สำหรับ login docker registry
- `ENABLE_PORTAINER_DEPLOYMENT` – ตั้งค่าเป็น `true` หากต้องการ trigger Portainer auto redeploy
- `PORTAINER_*` – กำหนด URL, credentials และ Webhook URL

> ⚠️ ควรตั้งค่าเหล่านี้ผ่าน environment variable หรือ `.env` file เพื่อความปลอดภัย

---
