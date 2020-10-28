#!/bin/sh
# Developer Setup
# by Jim Barrett <barrettj1971@gmail.com>
# License: GNU GPLv3

# repo and programs list

dotfiles="https://github.com/jimbarrett/arch-configs.git"
programs="https://raw.githubusercontent.com/jimbarrett/arch-dev-setup/main/programs.csv"

# functions used in installation process
error() {\
	clear;
	printf "ERROR: $1\n";
	exit;
}
isroot() {\
	pacman -Syu --noconfirm || error "You must be logged in as the root user in order to run this script."
}
getusername() {\
	clear;
	echo "First, we need a name for the new user account."
	read username
	while ! echo "$username" | grep "^[a-z][a-z0-9_-]*$" >/dev/null 2>&1; do
		echo "Invalid username."
		echo "Username must begin with a letter and can only contain uppercase letters, - and _"
		read username
	done
}
getpassword() {\
	clear;
	echo "Password for new user:"
	read pass1
	echo "Retype password:"
	read pass2
	while ! [ $pass1 = $pass2 ]; do
		unset pass1
		unset pass2
		echo "Passwords do not match. Try again."
		read pass1
		echo "Retype password:"
		read pass2
	done
	unset pass2
}
usercheck() {\
	! (getent passwd $username >/dev/null) 2>&1 || userexists
}
userexists() {\
	clear;
	echo "A user with that username already exists."
	echo "We can continue with the installation, but any conflicting dot files will be overwritten and the password for that user will be updated."
	echo "Do you want to cotinue?"
	select cont in "Yes" "No"; do
		case $cont in
			Yes ) break;;
			No ) error "User exited";;
		esac
	done
}
createuser() {\
	clear;
	echo "Adding user..."
	useradd -m -g wheel -s /bin/bash $username >/dev/null 2>&1 ||
	usermod -a -G wheel $username && mkdir -p /home/$username && chown $username:wheel /home/$Username
	echo $username:$pass1 | chpasswd
	unset pass1 ;
}
refreshkeys() {\
	clear;
	echo "Refreshing Arch keyring..."
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
}
installreqs() {\
	clear;
	echo "Installing 'basedevel' and 'git' for installing other software."
	pacman --noconfirm --needed -S base-devel git >/dev/null 2>&1
}
updateperms() {\
	clear;
	echo "Updating sudoers file..."
	sed -i "/#DEVPERMS/d" /etc/sudoers
	echo "%wheel ALL=(ALL) NOPASSWD: ALL #DEVPERMS" >> /etc/sudoers ;
}
installyay() {\
	[ -f "/usr/bin/yay" ] || (
	clear;
	echo "Installing yay..."
	cd /tmp || exit
	rm -rf /tmp/yay*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz &&
	sudo -u $username tar -xvf yay.tar.gz >/dev/null 2>&1 &&
	cd "yay" &&
	sudo -u $username makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;
}
maininstall() {\
	clear;
	echo "Installing \`$1\` ($n of $total). $1 $2"
	pacman --noconfirm --needed -S $1 >/dev/null 2>&1
}
aurinstall() {\
	clear;
	echo "Installing \`$1\` ($n of $total) from the AUR. $1 $2"
	sudo -u $username yay -S --noconfirm $1 >/dev/null 2>&1
}
loop() {\
	curl -Ls $programs | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		newcomment="$(echo $comment | sed "s/\(^\"\|\"$\)//g")"
		case $tag in
			"") maininstall "$program" "$newcomment" ;;
			"A") aurinstall "$program" "$newcomment" ;;
		esac
	done < /tmp/progs.csv ;
}
downloaddots() {\
	clear;
	echo "Downloading dot files to /home/$username..."
	dir=$(mktemp -d)
	[ ! -d /home/$username ] && mkdir -p /home/$username && chown -R $username:wheel /home/$username
	chown -R $username:wheel $dir
	sudo -u $username git clone --depth 1 $dotfiles $dir/gitrepo >/dev/null 2>&1 &&
	sudo -u $username cp -rfT $dir/gitrepo /home/$username
}
serviceinit() {\
	for service in $@; do
		clear;
		echo "Enabling $service..."
		systemctl enable $service
		systemctl start $service
	done ;
}
systembeepoff() {\
	clear;
	echo "Turning off system error beep..."
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
}
resetpulse() {\
	clear;
	echo "Resetting Pulseaudio..."
	killall pulseaudio
	sudo -n $username pulseaudio --start ;
}

# Let's do it
isroot
clear
echo "Welcome!"
echo "This will install a full dev environment. Are you ready? (y/n)"
while true; do
	read doit
	case $doit in
		[Yy]* ) break;;
		[Nn]* ) error "User exited.";;
		* ) echo "Please enter yes or no.";;
	esac
done

getusername
getpassword
usercheck

echo "Ok. That should be all we need."
read -n 1 -s -r -p "Press any key to continue..."

createuser || error "Couldn't create the user"

refreshkeys || error "Couldn't refresh the keyring."

installreqs || error "Couldn't install required packages."

updateperms || error "Couldn't update permissions."

sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

installyay || error "Couldn't install yay."

loop

downloaddots || error "Couldn't download dot files."

rm -f /home/$username/README.md /home/$username/LICENSE

chsh -s /usr/bin/zsh $username

# install nvm
sudo -u $username mkdir /home/$username/.local/.nvm &&
export NVM_DIR=/home/$username/.local/.nvm &&
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.36.0/install.sh | bash

[ -f /usr/bin/pulseaudio ] && resetpulse

serviceinit NetworkManager cronie org.cups.cupsd.service

systembeepoff

echo "Ok. It looks like everything went well."
echo "You should be able to log out and log back in as your new user."
