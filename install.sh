#!/bin/bash

set -e

clear

echo "========================================="
echo "         O11PRO INSTALLER"
echo "========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
echo "❌ Execute como root."
exit 1
fi

read -p "🔢 Informe a porta do painel [8484]: " PORTA
PORTA=${PORTA:-8484}

if ! [[ "$PORTA" =~ ^[0-9]+$ ]]; then
echo "❌ Porta inválida."
exit 1
fi

echo ""
echo "📦 Atualizando pacotes..."
apt update

echo ""
echo "🎬 Instalando FFmpeg..."
apt install -y ffmpeg curl wget unzip ca-certificates

echo ""
echo "🛑 Parando instalação anterior (se existir)..."

systemctl stop o11pro >/dev/null 2>&1 || true
systemctl disable o11pro >/dev/null 2>&1 || true

rm -f /etc/systemd/system/o11pro.service

echo ""
echo "📁 Preparando diretório..."

rm -rf /opt/pro
mkdir -p /opt/pro

echo ""
echo "⬇️ Baixando arquivos..."

curl -L -o /tmp/pro.zip 
"https://github.com/mundialtecdev/pro/raw/main/pro.zip"

echo ""
echo "📦 Extraindo arquivos..."

unzip -o /tmp/pro.zip -d /opt/pro

rm -f /tmp/pro.zip

chmod -R 755 /opt/pro

if [ ! -f /opt/pro/o11pro ]; then
echo "❌ Binário /opt/pro/o11pro não encontrado."
exit 1
fi

chmod +x /opt/pro/o11pro

echo ""
echo "⚙️ Criando serviço systemd..."

cat > /etc/systemd/system/o11pro.service << EOF
[Unit]
Description=O11Pro Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/pro
ExecStart=/opt/pro/o11pro -p ${PORTA} -f /usr/bin/ffmpeg
Restart=always
RestartSec=5
User=root
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo ""
echo "🚀 Iniciando serviço..."

systemctl enable o11pro
systemctl restart o11pro

echo ""
echo "⏳ Aguardando inicialização..."

sleep 8

PASSWORD=$(journalctl -u o11pro -n 100 --no-pager | grep "Use temporary account" | tail -1 | awk -F'admin / ' '{print $2}')

PUBLIC_IP=$(curl -s https://api.ipify.org || true)

if [ -z "$PUBLIC_IP" ]; then
PUBLIC_IP="SEU_IP"
fi

clear

echo ""
echo "========================================="
echo "      ✅ O11PRO INSTALADO COM SUCESSO"
echo "========================================="
echo ""

echo "🌐 URL:"
echo "http://${PUBLIC_IP}:${PORTA}"
echo ""

echo "👤 Usuário:"
echo "admin"
echo ""

echo "🔑 Senha Temporária:"
echo "${PASSWORD}"
echo ""

echo "📂 Diretório:"
echo "/opt/pro"
echo ""

echo "📋 Comandos úteis:"
echo "systemctl status o11pro"
echo "journalctl -u o11pro -f"
echo "systemctl restart o11pro"
echo ""

echo "✅ Instalação finalizada."
