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
apt update -y

echo
echo "📦 Instalando dependências..."
apt install -y curl wget unzip ffmpeg ca-certificates file

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
echo "📦 Verificando arquivo baixado..."

if ! file /tmp/pro.zip | grep -qi "zip"; then
echo "❌ O arquivo baixado não é um ZIP válido"
file /tmp/pro.zip
exit 1
fi

echo
echo "📂 Extraindo arquivos..."

unzip -oq /tmp/pro.zip -d /opt/pro

rm -f /tmp/pro.zip

if [ ! -f /opt/pro/o11pro ]; then
echo "❌ Binário não encontrado:"
echo "   /opt/pro/o11pro"
echo
echo "Arquivos encontrados:"
find /opt/pro -type f
exit 1
fi

chmod +x /opt/pro/o11pro

echo
echo "⚙️ Criando serviço systemd..."

cat > /etc/systemd/system/o11pro.service <<EOF
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

echo
echo "🔄 Recarregando systemd..."

systemctl daemon-reload

echo
echo "🚀 Iniciando serviço..."

systemctl enable o11pro
systemctl restart o11pro

echo
echo "⏳ Aguardando inicialização..."

sleep 10

PASSWORD=$(journalctl -u o11pro --no-pager -n 100 | grep "Use temporary account" | tail -1 | sed 's/.*admin / //')

PUBLIC_IP=$(curl -s https://api.ipify.org || true)

if [ -z "$PUBLIC_IP" ]; then
PUBLIC_IP="SEU_IP"
fi

STATUS=$(systemctl is-active o11pro || true)

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
echo "🔑 Senha Temporária:"
echo "${PASSWORD}"
echo
echo "📂 Diretório:"
echo "/opt/pro"
echo
echo "📊 Status:"
echo "${STATUS}"
echo
echo "📋 Comandos úteis:"
echo "systemctl status o11pro"
echo "journalctl -u o11pro -f"
echo "systemctl restart o11pro"
echo
echo "✅ Instalação finalizada."
echo
