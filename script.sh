#!/bin/bash

set -ex

V_MAJ=$1
V_MIN=$2
VY=$3
VM=$4
VD=$5

FILE_NAME=gcc-arm-none-eabi-$V_MAJ.$V_MIN-20$VY.$VM

aria2c -i - <<EOF
https://developer.arm.com/-/media/Files/downloads/gnu-rm/$V_MAJ.$V_MIN-20$VY.$VM/$FILE_NAME-win32.zip
  always-resume
  conditional-get
https://developer.arm.com/-/media/Files/downloads/gnu-rm/$V_MAJ.$V_MIN-20$VY.$VM/$FILE_NAME-x86_64-linux.tar.bz2
  always-resume
  conditional-get
https://developer.arm.com/-/media/Files/downloads/gnu-rm/$V_MAJ.$V_MIN-20$VY.$VM/$FILE_NAME-aarch64-linux.tar.bz2
  always-resume
  conditional-get
https://developer.arm.com/-/media/Files/downloads/gnu-rm/$V_MAJ.$V_MIN-20$VY.$VM/$FILE_NAME-mac.tar.bz2
  always-resume
  conditional-get
EOF

DIRS=(win32 x86_64-linux aarch64-linux mac)

echo "Unpacking files"
rm -rf "${DIRS[@]}"
mkdir -p "${DIRS[@]}"
unzip -q $FILE_NAME-win32.zip -d win32 &
tar xf $FILE_NAME-x86_64-linux.tar.bz2 -C x86_64-linux &
tar xf $FILE_NAME-aarch64-linux.tar.bz2 -C aarch64-linux &
tar xf $FILE_NAME-mac.tar.bz2 -C mac &
wait

for d in "${DIRS[@]}"; do
  rm -rf "$PWD/$d/$FILE_NAME/share/doc"
done

V_PATCH=$(./x86_64-linux/$FILE_NAME/bin/arm-none-eabi-gcc -v 2>&1 | awk '/gcc version/ { split($3, a, "."); print a[3];  }')

for d in "${DIRS[@]}"; do
  cp -f ./package-template.json ./$d/$FILE_NAME/package.json
  sed -i -e "s/{V_MAJ}/$V_MAJ/g" -e "s/{V_MIN}/$(printf "%02d" "$V_MIN")/g" -e "s/{V_PATCH}/$(printf "%02d" "$V_PATCH")/g" ./$d/$FILE_NAME/package.json
  sed -i -e "s/{VY}/$(printf "%02d" "$VY")/g" -e "s/{VM}/$(printf "%02d" "$VM")/g" -e "s/{VD}/$(printf "%02d" "$VD")/g" ./$d/$FILE_NAME/package.json
done

sed -i -e 's/{SYSTEM}/"darwin_x86_64"/g' ./mac/$FILE_NAME/package.json
sed -i -e 's/{SYSTEM}/"linux_x86_64"/g' ./x86_64-linux/$FILE_NAME/package.json
sed -i -e 's/{SYSTEM}/"linux_aarch64"/g' ./aarch64-linux/$FILE_NAME/package.json
sed -i -e 's/{SYSTEM}/"windows_amd64", "windows_x86"/g' ./win32/$FILE_NAME/package.json

for d in "${DIRS[@]}"; do
  pio package pack "$d/$FILE_NAME/" &
  # pio package publish "$d/$FILE_NAME/" &
done
wait
