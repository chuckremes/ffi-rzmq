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

wget http://download.zeromq.org/zeromq-4.2.2.tar.gz
tar -xvf zeromq-4.2.2.tar.gz
cd zeromq-4.2.2
./autogen.sh
./configure && make check
sudo make install
sudo ldconfig

bundle exec rake spec
