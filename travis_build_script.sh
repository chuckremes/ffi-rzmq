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

BASE="zeromq-4.1.6"
TARBALL="${BASE}.tar.gz"
wget https://github.com/zeromq/zeromq4-1/releases/download/v4.1.6/$TARBALL
tar -xvf $TARBALL
cd $BASE
./autogen.sh
./configure && make check
sudo make install
sudo ldconfig

bundle exec rake spec
