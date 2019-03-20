#!/bin/bash
clear

#On définit les variable d'environnement utile
DEV=/dev/sdb	#accès à la clé
#Point de montage de la clé
ROOT=/mnt/root-rpi	
BOOT=/mnt/boot-rpi
PWD=$(pwd)	#Accès au dossier d'installation
LEMB=$PWD	#On fixe le LEMB
CROSS_COMPILE="$LEMB/build/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-"
GCC_CROISE="$LEMB/build/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-gcc"


#vérifier qu'on est root
if [ $(id -u) -ne 0 ]	#On vérifie si l'id utilisateur n'est pas égal à 0 (id de root)
then
	echo "il faut etre root !" 1>&2 #Si l'id est différent de 0 on éjecte l'utilisateur avec un message explicatif
	exit 1
fi

#Préparation de l'environnement de travail
mkdir /mnt/root-rpi 2>>/dev/null
mkdir /mnt/boot-rpi 2>>/dev/null

echo -n "Voulez-vous préparer l'environnement de travail ? [Y-n]" #On demande confirmation à l'utilisateur
read REP

if [ "$REP" != "n" ]
then
	echo -n "Nous allons préparer l'environnement de travail, cela peut prendre quelque minutes"
	read PAUSE
	tar xzvf src/busybox-1.29.3.tar.gz
	tar xvzf src/tools-master.tar.gz
	tar xvzf src/wiringPi.tar.gz

	mv busybox-1.29.3 build
	mv tools-master build
	mv wiringPi build 

	clear
fi

echo -n "Brancher la clef et appuyer sur ENTREE"	#On avertit l'utilisateur que la clé doit être branché
read PAUSE
clear

#detection clef par dmesg
dmesg | grep sd | tail #Permet de voir si un périphérique est connecté

echo -n "Utiliser $DEV [Y-n] ? " #On demande confirmation à l'utilisateur
read REP

if [ "$REP" == "n" ]
then
	echo -n "Indiquer le peripherique : " #Sinon on lui demande d'indiquer l'accès au périphérique
	read DEV
fi

PARTBOOT=${DEV}1	#On définit PARTBOOT comme étant ex: /dev/sdb1
PARTROOT=${DEV}2	#On définit PARTROOT comme étant ex: /dev/sdb2


echo "Utilisation de $PARTBOOT et $PART-ROOT"
clear

#DEMONTAGE DE LA CLE
umount $PARTBOOT #On la démonte nécessairement pour pouvoir la remonter plus tard sur le bon point de montage
umount $PARTROOT

#PARTITIONNER
echo -n "Faut il partitionner [y-N] ? " 
read REP

if [ "$REP" == "y" ]
then

	sfdisk $DEV --delete 1 2>>/dev/null
	sfdisk $DEV --delete 2 2>>/dev/null

	sfdisk $DEV < data/sdb.out

	echo -n "ENTREE pour continuer"
	read PAUSE	
fi
clear

#FORMATAGE
echo -n "Faut il formater [y-N] ? "
read REP

if [ "$REP" == "y" ]
then
	mkfs.vfat $PARTBOOT
	mkfs.ext4 $PARTROOT
	echo -n "ENTREE pour continuer"
	read PAUSE
fi

#MONTAGE
echo "Montage de la cle"
mount $PARTBOOT $BOOT
mount $PARTROOT $ROOT
df -h | grep $DEV
echo -n "ENTREE pour continuer"
read PAUSE
clear

#Copie du boot vers la pertition boot
echo -n "Copie des fichier de Boot "
cp data/boot/* $BOOT -r
echo -n "ENTREE pour continuer"
read PAUSE
clear

#installation de busybox
echo -n "Création des repertoire dans la partition Root "
mkdir  $ROOT/bin  $ROOT/dev  $ROOT/etc  $ROOT/home  $ROOT/lib  $ROOT/mnt  $ROOT/proc  $ROOT/root  $ROOT/sbin  $ROOT/sys  $ROOT/tmp  $ROOT/usr  $ROOT/var
mkdir  $ROOT/dev/pts  $ROOT/etc/init.d $ROOT/usr/bin  $ROOT/usr/sbin 

echo -n "ENTREE pour continuer"
read PAUSE

echo -n "Installation de busybox"

cd build/busybox-1.29.3
make CROSS_COMPILE="$CROSS_COMPILE" CONFIG_PREFIX=$ROOT install

cp $LEMB/build/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/arm-linux-gnueabihf/libc/lib/arm-linux-gnueabihf/* $ROOT/lib -r

cp $LEMB/data/inittab $ROOT/etc
cp $LEMB/data/rcS $ROOT/etc/init.d
cp $LEMB/data/azerty.kmap $ROOT/etc

chmod +x $ROOT/etc/init.d/rcS 2>>/dev/null

echo -n "ENTREE pour continuer"
read PAUSE
clear

#nstallation wiringPi
echo -n "Souhaitez-vous installer la librairie wiringPi (et le programme gpio) ? [Y-n]"
read REP

if [ "$REP" != "n" ]
then
	cd $LEMB/build/wiringPi/wiringPi
	make clean
	make GCC_CROISE=$GCC_CROISE all
	make GCC_CROISE=$GCC_CROISE install

	cd $LEMB/build/wiringPi/devLib
	make clean
	make GCC_CROISE=$GCC_CROISE all
	make GCC_CROISE=$GCC_CROISE install

	cd $LEMB/build/wiringPi/gpio
	make clean
	make GCC_CROISE=$GCC_CROISE all
	make GCC_CROISE=$GCC_CROISE install

	cp $ROOT/lib/libwiringPi.so.2.46 /lib
	cp $ROOT/lib/libwiringPiDev.so.2.46 /lib

	rm $ROOT/lib/libwiringPi.so
	rm $ROOT/lib/libwiringPiDev.so

	ln /lib/libwiringPi.so.2.46 $ROOT/lib/libwiringPi.so -s
	ln /lib/libwiringPiDev.so.2.46 $ROOT/lib/libwiringPiDev.so -s

	rm /lib/libwiringPi.so.2.46
	rm /lib/libwiringPiDev.so.2.46
fi