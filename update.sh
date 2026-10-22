#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Buscando atualizações no repositório..."
git pull origin main

echo "==> Recompilando e atualizando a instalação do Focus..."
./install.sh "$@"

echo "==> Focus Browser atualizado com sucesso para a versão mais recente!"
