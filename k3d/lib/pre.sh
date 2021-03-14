#! /bin/sh

OSTYPE=`uname -s`
if [ "x$OSTYPE" = "xDarwin" ]; then
  PLATFORM=macos
  DLLEXT=dylib
else
  PLATFORM=linux-amd64
  DLLEXT=so
fi

DRB_ROOT=../..
mkdir -p ../native/$PLATFORM

ls $DRB_ROOT/include

$DRB_ROOT/dragonruby-bind --ffi-module=K3d --output=../native/k3d-bindings.c k3d.c
clang \
    -isystem $DRB_ROOT/include/ -I. \
    -fPIC -shared ../native/k3d-bindings.c -o ../native/$PLATFORM/k3d.$DLLEXT
