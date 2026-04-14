#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "Debloat: purge default Ubuntu bloat"

require_ubuntu

# Games
GAMES=(
    aisleriot
    gnome-mahjongg
    gnome-mines
    gnome-sudoku
    gnome-2048
    gnome-chess
    gnome-nibbles
    gnome-robots
    gnome-taquin
    gnome-tetravex
    lightsoff
    four-in-a-row
    five-or-more
    hitori
    hoichess
    iagno
    quadrapassel
    swell-foop
    tali
)

# Office / productivity GUI apps
OFFICE=(
    libreoffice-core
    libreoffice-common
    libreoffice-writer
    libreoffice-calc
    libreoffice-impress
    libreoffice-draw
    libreoffice-math
    libreoffice-base
    libreoffice-gnome
    libreoffice-gtk3
    libreoffice-help-common
    libreoffice-help-en-us
    libreoffice-style-colibre
    thunderbird
    thunderbird-gnome-support
    evolution
    evolution-common
)

# Media / misc GNOME apps
MEDIA_MISC=(
    rhythmbox
    rhythmbox-data
    rhythmbox-plugins
    shotwell
    cheese
    transmission-gtk
    transmission-common
    simple-scan
    remmina
    deja-dup
    gnome-todo
    gnome-contacts
    gnome-weather
    gnome-maps
    gnome-characters
    gnome-logs
    gnome-font-viewer
    gnome-clocks
    gnome-calendar
    yelp
)

# Firefox — both the deb/snap packaging transitional packages and any real install
FIREFOX=(
    firefox
    firefox-esr
)

apt_purge "${GAMES[@]}"
apt_purge "${OFFICE[@]}"
apt_purge "${MEDIA_MISC[@]}"
apt_purge "${FIREFOX[@]}"

if ! $VERIFY_MODE; then
    log_info "autoremoving leftover dependencies"
    sudo apt-get -y autoremove --purge
    log_ok "debloat complete"
fi
