#!/usr/bin/env bash

# Прерывать выполнение при ошибках
set -euo pipefail

echo "🚀 Начинаем установку окружения..."

# 1. Проверка на root (скрипт должен запускаться от обычного пользователя с sudo-доступом)
if [ "$EUID" -eq 0 ]; then
  echo "❌ Пожалуйста, не запускайте этот скрипт от имени root (используйте обычного пользователя)."
  exit 1
fi

# Путь к директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# ЭТАП 1: Подключение репозиториев CachyOS
# -----------------------------------------------------------------------------
echo "📦 Настройка репозиториев CachyOS..."
sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key F3B607488DB35A47
sudo pacman -U --noconfirm 'https://mirror.cachyos.org/repo/v3/cachyos/x86_64/cachyos-keyring-4-1-any.pkg.tar.zst' \
                           'https://mirror.cachyos.org/repo/v3/cachyos/x86_64/cachyos-mirrorlist-18-1-any.pkg.tar.zst'

# Добавление репозиториев в pacman.conf, если их там еще нет
if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    sudo sed -i '1s/^/[cachyos]\nInclude = \/etc\/mirrorlist.cachyos\n\n/' /etc/pacman.conf
fi

sudo pacman -Syu --noconfirm

# -----------------------------------------------------------------------------
# ЭТАП 2: Установка базовых утилит и AUR-помощника
# -----------------------------------------------------------------------------
echo "🛠️ Установка базовых пакетов и paru..."
sudo pacman -S --needed --noconfirm base-devel git wget curl

if ! command -v paru &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    cd /tmp/paru-bin && makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
fi

# -----------------------------------------------------------------------------
# ЭТАП 3: Ядро, Планировщик и Драйверы
# -----------------------------------------------------------------------------
echo "🧠 Установка оптимизированного ядра и игровых утилит..."
sudo pacman -S --needed --noconfirm linux-cachyos-bore-lto linux-cachyos-bore-lto-headers
sudo pacman -S --needed --noconfirm scx-scheds # Планировщики sched-ext
sudo pacman -S --needed --noconfirm cachyos-gaming-meta cachyos-hooks

# Включение службы scx (выбери нужный планировщик, например scx_rusty или scx_lavd)
sudo systemctl enable --now scx

# -----------------------------------------------------------------------------
# ЭТАП 4: Системные компоненты, Шрифты и Аудио
# -----------------------------------------------------------------------------
echo "🔊 Настройка аудио и системных интерфейсов..."
sudo pacman -S --needed --noconfirm pipewire pipewire-pulse wireplumber xdg-desktop-portal-gnome qt6-wayland ttf-jetbrains-mono-nerd

# -----------------------------------------------------------------------------
# ЭТАП 5: Основной софт (CLI, TUI, Dev, GUI)
# -----------------------------------------------------------------------------
echo "💻 Установка приложений..."

# CLI / TUI
sudo pacman -S --needed --noconfirm vim python uv yazi lsd cava fzf ripgrep

# Графика, WM и Дисплейный менеджер
sudo pacman -S --needed --noconfirm niri mpv thunderbird telegram-desktop
paru -S --needed --noconfirm silent-sddm-theme ghostty-git quickshell-git qylock-git

# Программы (Dev, Multimedia, Games)
paru -S --needed --noconfirm pycharm-community-edition vscodium-bin spotify steam vesktop-bin whoami-project-git

# Активация SDDM
sudo systemctl enable sddm

# -----------------------------------------------------------------------------
# ЭТАП 6: Накатывание конфигов (Dotfiles)
# -----------------------------------------------------------------------------
echo "⚙️ Копирование конфигурационных файлов..."

mkdir -p "$HOME/.config"

# Пример безопасного копирования/линковки:
# Настройки Ghostty
if [ -d "$SCRIPT_DIR/configs/ghostty" ]; then
    rm -rf "$HOME/.config/ghostty"
    ln -s "$SCRIPT_DIR/configs/ghostty" "$HOME/.config/ghostty"
fi

# Настройки MPV (включая скрипты ввода)
if [ -d "$SCRIPT_DIR/configs/mpv" ]; then
    rm -rf "$HOME/.config/mpv"
    ln -s "$SCRIPT_DIR/configs/mpv" "$HOME/.config/mpv"
fi

# Настройки Niri
if [ -d "$SCRIPT_DIR/configs/niri" ]; then
    rm -rf "$HOME/.config/niri"
    ln -s "$SCRIPT_DIR/configs/niri" "$HOME/.config/niri"
fi

# -----------------------------------------------------------------------------
# ЭТАП 7: Установка Anime4K шейдеров для MPV
# -----------------------------------------------------------------------------
echo "🎬 Установка шейдеров Anime4K..."
MPV_SHADERS_DIR="$HOME/.config/mpv/shaders"
mkdir -p "$MPV_SHADERS_DIR"
# Скачиваем последнюю версию Anime4K (пример для v4.0.1, можно адаптировать под динамический curl)
wget -q --show-progress -O /tmp/Anime4K.zip https://github.com/bloc97/Anime4K/releases/download/v4.0.1/Anime4K_v4.0.1.zip
unzip -o /tmp/Anime4K.zip -d "$MPV_SHADERS_DIR"

echo "🎉 Установка завершена! Перезагрузите систему в новое ядро cachyos-bore-lto."
