#!/bin/bash
[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

heading ()
{
	echo -e "\n\n+- $1\n"
}

echo -e '\n\n\n\n####################\n#'
echo -e '#  This will install MilwaukeeMakerspacePiFobReader on this system'
echo -e '#\n####################\n'
mkdir -p /opt/MmsPiFobReader

# Set Reader Id
while ! [[ $READERID =~ ^-?[0-9]+$ ]]
do
	heading 'Type the Reader Id you wish to set and press [ENTER]:'
	read READERID
done

echo $READERID > /opt/MmsPiFobReader/readerid.txt

# Set Server
heading '[Optional] If you wish you can hardcode the address of your API Server by typing it and pressing [ENTER]:\n+- If you wish to use SSDP just press [ENTER] without typing anything:'
read SERVER

if [[ -n "${SERVER/[ ]*\n/}" ]]
then
	echo $SERVER > /opt/MmsPiFobReader/server.txt
fi

# Work out of root user home
cd /root

# Update the OS
heading 'Updating Operating System'
apt-get -y update
apt-get -y dist-upgrade

# Install needed libraries
heading 'Installing Libraries'
apt-get -y install git libunwind8 wiringpi busybox-syslogd ntp

# Remove unneeded libraries
heading 'Removing Libraries'
apt-get -y purge anacron unattended-upgrades logrotate dphys-swapfile rsyslog

# Install SSH Key
mkdir ~/.ssh && touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAvaHWKFt0zD0HAiv/PrTT/Qx0g4RxRAnbCrxO2C9oqPifXtcuKTW0aWNp0NyQMEQz/KFLZtzyRJi3A7rjEOH/6qotuhV7T5KJT39OgCL4A4vK1e4R+h8ZmitgIPGR5HYzW8X+1ODhGhO04nLh7LELHdYxy9gZWaMFNC3F1hlkCJF3WepkMClFoqt4pv8UHA4yWjS8eaudvcdPnoSdO2bAAuoCao/tB78dJomkxV8laDENb5wgwqNv/1p3yxTK+y1srxRcJyr6dFS6us9puVEfbpWFuMrW9v/NxylcCa1TOp1F3iKCkg8WQQPNbTC7drIh9J8Ntma/1wFPsFHfQcQ0oqgz0QDK/z8F1w1PQmh+exlK5gk0769Zt4EaTUJ8xDFf++fBIFVgGE8FnLjHRmaNfGWe3Uw0Kd9pzbXfOmcqMxvKCapTKG0c/j7fOJUIXE4BIYFB00FezEQs4e5d+rZ5Pc6SW3ue/4fB3+JoI4Kh1C2lx7SreODhgkc+uLYK31W/Z/jtJ3CwYSLz2EIdwJXLGHyPavhTxLi6mhEUpFNI85NUIOBxc2Fhx34kDEbrGPL7tiLiJo4ZfIVEog8ghgcBnxVuDFlMi/poAU8cLO2USAx0XCkF2kkyeuiBHuze/qzjO0YEXxeEapgbJnDIO0kJHONiLmjAV0DysZ1sNV8EBhs= MmsPiFobReader' > ~/.ssh/authorized_keys

# Install .Net Core
heading 'Installing .Net Core'
wget https://download.visualstudio.microsoft.com/download/pr/201cbc49-c122-4653-a6c6-0680643d9a26/1951cfc077d868a31563a5a172d18d78/dotnet-sdk-2.1.500-linux-arm.tar.gz
mkdir -p /opt/dotnet 
tar zxf dotnet-sdk-2.1.500-linux-arm.tar.gz -C /opt/dotnet --checkpoint=.10
ln -s /opt/dotnet/dotnet /usr/local/bin/
rm -f dotnet-sdk-2.1.500-linux-arm.tar.gz

# Download Source
heading 'Downloading Source'
git clone https://github.com/DanDude0/MilwaukeeMakerspacePiFobReader.git

# Build Application
heading 'Building MmsPiFobReader Application'
cd /root/MilwaukeeMakerspacePiFobReader/MmsPiFobReader
dotnet publish -v normal -c Release -o /opt/MmsPiFobReader

# Install Systemd Unit
heading 'Installing Systemd Unit'
cat > /etc/systemd/system/MmsPiFobReader.service << 'END'
[Unit]
Description=Milwaukee Makerspace Pi Fob Reader Client
After=network.target

[Service]
WorkingDirectory=/opt/MmsPiFobReader
ExecStart=/usr/local/bin/dotnet /opt/MmsPiFobReader/MmsPiFobReader.dll
KillMode=process
Restart=always
User=root

[Install]
WantedBy=multi-user.target
END
systemctl enable MmsPiFobReader

# Improve readability of tiny console
heading 'Setting Console Font'
cat > /etc/default/console-setup << 'END'
# CONFIGURATION FILE FOR SETUPCON

# Consult the console-setup(5) manual page.

ACTIVE_CONSOLES="/dev/tty[1-6]"

CHARMAP="UTF-8"

CODESET="guess"
FONTFACE="Terminus"
FONTSIZE="6x12"

VIDEOMODE=

# The following is an example how to use a braille font
# FONT='lat9w-08.psf.gz brl-8x8.psf'
END

# Disable LEDs
heading 'Disabling LEDs'
cat > /etc/rc.local << 'END'
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Print the IP address
_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  printf "My IP address is %s\n" "$_IP"
fi

echo none >/sys/class/leds/led0/trigger
echo none >/sys/class/leds/led1/trigger
echo 0 >/sys/class/leds/led0/brightness
echo 0 >/sys/class/leds/led1/brightness

exit 0
END

echo 'Install completed, reboot to start reader';