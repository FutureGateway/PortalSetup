#!/bin/bash
#
# docker-setup.sh - Riccardo Bruno INFN.CT <riccardo.bruno@ct.infn.it>
#
cd /root
IP=$(ifconfig | grep  -A 2 eth0 | grep inet\ addr | awk -F':' '{ print $2 }' | awk '{ print $1 }' | xargs echo)
echo "$IP    futuregateway" >> /etc/hosts
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
apt-get update -y
apt-get install -y wget openssh-client openssh-server 
adduser --disabled-password --gecos "" futuregateway
mkdir -p /root/.ssh
mkdir -p /home/futuregateway/.ssh
chown futuregateway:futuregateway /home/futuregateway/.ssh
echo "#FGSetup remove the following after installation" >> /etc/sudoers
echo "ALL  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
service ssh start
ssh-keyscan -H -p 22 -t rsa futuregateway >> $HOME/.ssh/known_hosts
cat > /root/installFG.sh <<EOF
#!/bin/bash
touch /home/futuregateway/.installingFG
cd /root
wget https://github.com/FutureGateway/PortalSetup/raw/master/Ubuntu_14.04/fgSetup.sh
chmod +x fgSetup.sh
cat /dev/zero | ssh-keygen -q -N ""
cat /root/.ssh/id_rsa.pub >> /home/futuregateway/.ssh/authorized_keys
./fgSetup.sh futuregateway futuregateway 22 \$(cat /root/.ssh/id_rsa.pub)
rm -f /home/futuregateway/.installingFG
EOF
chmod +x /root/installFG.sh
./installFG.sh
cd -
