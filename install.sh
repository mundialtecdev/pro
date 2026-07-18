#!/bin/bash

set -e

clear

echo "========================================="
echo "         O11PRO INSTALLER"
echo "========================================="
echo

if [ "$EUID" -ne 0 ]; then
echo "❌ Execute como root"
exit 1
fi

read -p "🔢 Informe a porta do painel [8484]: " PORTA
PORTA=${PORTA:-8484}

if ! [[ "$PORTA" =~ ^[0-9]+$ ]]; then
echo "❌ Porta inválida"
exit 1
fi

echo
echo "📦 Atualizando repositórios..."
apt-get update -y

echo
echo "📦 Instalando dependências..."
apt-get install -y 
curl 
wget 
unzip 
ffmpeg 
ca-certificates

echo
echo "🛑 Removendo instalação anterior..."

systemctl stop o11pro >/dev/null 2>&1 || true
systemctl disable o11pro >/dev/null 2>&1 || true

rm -f /etc/systemd/system/o11pro.service

rm -rf /opt/pro
mkdir -p /opt/pro

echo
echo "⬇️ Baixando pro.zip..."

DOWNLOAD_URL="https://raw.githubusercontent.com/mundialtecdev/pro/main/pro.zip"

curl -fL "$DOWNLOAD_URL" -o /tmp/pro.zip

if [ ! -f /tmp/pro.zip ]; then
echo "❌ Falha ao baixar pro.zip"
exit 1
fi

echo
echo "📦 Validando ZIP..."

if ! file /tmp/pro.zip | grep -qi "zip"; then
echo "❌ Arquivo baixado não é um ZIP válido"
exit 1
fi

echo
echo "📂 Extraindo arquivos..."

unzip -oq /tmp/pro.zip -d /opt/pro

rm -f /tmp/pro.zip

echo
echo "🔍 Localizando binário..."

BINARIO=$(find /opt/pro -type f -name "o11pro" | head -n1)

if [ -z "$BINARIO" ]; then
echo "❌ Binário o11pro não encontrado"
exit 1
fi

chmod +x "$BINARIO"

BIN_DIR=$(dirname "$BINARIO")

echo
echo "⚙️ Criando serviço systemd..."

cat >/etc/systemd/system/o11pro.service <<EOF
[Unit]
Description=O11Pro Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${BIN_DIR}
ExecStart=${BINARIO} -p ${PORTA} -f /usr/bin/ffmpeg
Restart=always
RestartSec=5
User=root
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo
echo "🚀 Iniciando serviço..."

systemctl enable o11pro >/dev/null
systemctl restart o11pro

echo
echo "⏳ Aguardando inicialização..."

sleep 10

PASSWORD=$(journalctl -u o11pro -n 100 --no-pager | grep "Use temporary account" | tail -1 | awk -F'admin / ' '{print $2}')

PUBLIC_IP=$(curl -s https://api.ipify.org || true)

[ -z "$PUBLIC_IP" ] && PUBLIC_IP="SEU_IP"

clear

echo
echo "========================================="
echo "      ✅ O11PRO INSTALADO COM SUCESSO"
echo "========================================="
echo
echo "🌐 Painel:"
echo "http://${PUBLIC_IP}:${PORTA}"
echo
echo "👤 Usuário:"
echo "admin"
echo
echo "🔑 Senha:"
echo "${PASSWORD}"
echo
echo "📂 Diretório:"
echo "${BIN_DIR}"
echo
echo "📋 Comandos úteis:"
echo "systemctl status o11pro"
echo "journalctl -u o11pro -f"
echo "systemctl restart o11pro"
echo
