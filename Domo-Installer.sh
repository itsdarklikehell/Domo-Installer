#!/bin/bash
MENU(){
  while [ 1 ]
do
CHOICE=$(
whiptail --title "Operative Systems" --menu "Make your choice" 16 100 9 \
	"1)" "Install Domoticz (Release)."   \
	"2)" "Install Domoticz. (Beta)"  \
	"3)" "Install Domoticz. (Sourcecode)" \
	"4)" "Update Domoticz." \
	"5)" "Backup Domoticz." \
	"exit)" "End script"  3>&2 2>&1 1>&3
)

case $CHOICE in

  "1)")
  whiptail --msgbox "This option is not implemented yet." 20 78
  echo  "Installing dependencies:"
  sudo apt-get install -y build-essential cmake libboost-dev libboost-thread-dev libboost-system-dev libsqlite3-dev subversion curl libcurl4-openssl-dev libusb-dev libudev-dev zlib1g-dev libssl-dev
  ##Download stable version:
  wget https://releases.domoticz.com/releases/release/domoticz_linux_armv7l.tgz
  tar -xvzf domoticz_linux_armv7l.tgz
  cd domoticz

	;;

  "2)")
  whiptail --msgbox "You chose option: $CHOICE" 20 78
  echo  "Installing dependencies:"
  sudo apt-get install -y build-essential cmake libboost-dev libboost-thread-dev libboost-system-dev libsqlite3-dev subversion curl libcurl4-openssl-dev libusb-dev libudev-dev zlib1g-dev libssl-dev
  ## Download beta version:
  wget https://releases.domoticz.com/releases/beta/domoticz_linux_armv7l.tgz
  ;;

	"3)")
  whiptail --msgbox "You chose option: $CHOICE" 20 78
  echo  "Installing dependencies:"
  sudo apt-get install -y build-essential cmake libboost-dev libboost-thread-dev libboost-system-dev libsqlite3-dev subversion curl libcurl4-openssl-dev libusb-dev libudev-dev zlib1g-dev libssl-dev
  cd ~
  git clone https://github.com/domoticz/domoticz.git ~/domoticz
  cd ~/domoticz
  cmake -DCMAKE_BUILD_TYPE=Beta .
  make
  cd ~
  wget http://archive.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.2l-1~bpo8+1_armhf.deb
  sudo dpkg -i libssl1.0.0_1.0.2l-1~bpo8+1_armhf.deb
  sudo usermod -a -G dialout $USER

  cd ~/domoticz
  nano domoticz.sh
  sudo cp domoticz.sh /etc/init.d
  sudo chmod +x /etc/init.d/domoticz.sh
  sudo update-rc.d domoticz.sh defaults
  sudo nano /etc/init.d/domoticz.sh
  ;;

	"4)")
  whiptail --msgbox "You chose option: $CHOICE" 20 78
  cd ~/domoticz/
  sudo /etc/init.d/domoticz.sh stop
  git pull
  make
  sudo /etc/init.d/domoticz.sh start
  ;;

	"5)")
  whiptail --msgbox "This option is not implemented yet." 20 78
  ;;

	"exit)")
  whiptail --msgbox "You chose option: $CHOICE" 20 78
  exit
  ;;

esac
done
exit
}

if (whiptail --title "Install Domoticz" --yesno "This script will install domoticz. are you sure?" 8 78) then
    echo "User selected Yes, exit status was $?."
    MENU
else
    echo "User selected No, exit status was $?."
    exit
fi
