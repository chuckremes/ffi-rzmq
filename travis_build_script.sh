#/bin/bash
set -ev

bundle install

sudo apt-get -qq update
sudo apt-get install libtool pkg-config build-essential autoconf automake wget 

git clone https://github.com/jedisct1/libsodium --branch stable
cd libsodium
./autogen.sh
./configure && make check
sudo make install
cd ..

VERSION="4.2.2"
BASE="zeromq-${VERSION}"
TARBALL="${BASE}.tar.gz"
wget https://github.com/zeromq/libzmq/releases/download/v$VERSION/$TARBALL
tar -xvf $TARBALL
cd $BASE
./autogen.sh
./configure && make check
sudo make install
sudo ldconfig

bundle exec rake spec
