#!/usr/bin/env bash
#
# osx helper script to run chrome in docker

set -e
set -u
set -o pipefail

command -v socat >/dev/null 2>&1 || brew install socat
command -v xquartz >/dev/null 2>&1 || {
  brew cask install xquartz
  echo "Open xquartz preferences (from menu) and check the box in security tab"
  echo "Then reboot to finish the setup."
  open -a Xquartz
  exit 0
}
if [ ! -f "$HOME/chrome.json" ]; then
  command -v wget >/dev/null 2>&1 || brew install wget
  wget https://raw.githubusercontent.com/jfrazelle/dotfiles/master/etc/docker/seccomp/chrome.json -O ~/chrome.json
fi
if [ ! -f "$HOME/.Xmodmap" ]; then
  echo 'clear control
clear mod2
keycode 63 = Control_L
keycode 67 = Control_L
keycode 71 = Control_R
add control = Control_L Control_R' > $HOME/.Xmodmap
fi

socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\" &
SOCAT_PID="$(echo $!)"
CHROME_UID="chrome-$RANDOM$RANDOM"
function finish {
  kill -9 "$SOCAT_PID"
  docker stop "$CHROME_UID"
  docker rm "$CHROME_UID"
}
trap finish EXIT SIGHUP SIGINT SIGTERM

printf "\n  !!!!!\n  open about://inspect - click Dedicated DevTools for Node - add 172.19.0.100:9229\n  !!!!!\n\n"

DISPLAY="$(ifconfig en0 | grep inet | tr -s ' ' | cut -d ' ' -f 2 ):0"
docker run -it \
  --net host \
  --cpuset-cpus 0 \
  --memory 512mb \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  -v $HOME/Downloads:/home/chrome/Downloads \
  -v $HOME/.config/google-chrome/:/data \
  --security-opt seccomp=$HOME/chrome.json \
  -v /dev/shm:/dev/shm \
  --name "$CHROME_UID" \
  jess/chrome \
  --bwsi \
  --no-default-browser-check \
  http://localhost:3111
