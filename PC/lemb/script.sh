#!/bin/bash
clear

#On définit les variable d'environnement utile
DEV=/dev/sdb	#accès à la clé
CLE=/mnt/cle	#Point de montage de la clé
PWD=$(pwd)	#Accès au dossier d'installation
LEMB=$PWD	#On fixe le LEMB


#ne pas oublié de donner les droits d'execution

#vérifier qu'on est root

if [ $(id -u) -ne 0 ]	#On vérifie si l'id utilisateur n'est pas égal à 0 (id de root)
then
	echo "il faut etre root !" 1>&2 #Si l'id est différent de 0 on éjecte l'utilisateur avec un message explicatif
	exit 1
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

PART=${DEV}1	#On définit PART comme étant ex: /dev/sdb1

echo "Utilisation de $PART"
clear

#DEMONTAGE DE LA CLE
umount $PART #On la démonte nécessairement pour pouvoir la remonter plus tard sur le bon point de montage

#PARTITIONNER
echo -n "Faut il partitionner [y-N] ? " 
read REP

if [ "$REP" == "y" ]
then

	#PARTITIONNEMENT --> 200 mo
	echo "Produire une partition de 200mo, type linux"
	fdisk $DEV
	echo -n "ENTREE pour continuer"
	read PAUSE

	
fi
clear

#FORMATAGE
echo -n "Faut il formater [y-N] ? "
read REP

if [ "$REP" == "y" ]
then
	mkfs.ext4 $PART
	echo -n "ENTREE pour continuer"
	read PAUSE
fi

#MONTAGE
echo "Montage de la cle"
mount $PART $CLE
df -h | grep sdc1
echo -n "ENTREE pour continuer"
read PAUSE
clear

#INSTALLATION DE GRUB
echo "Installation du grub"
mkdir $CLE/boot #Création du dossier boot sur la clé
grub-install --force --removable --boot-directory=$CLE/boot ${DEV}
echo -n "ENTREE pour continuer"
read PAUSE
clear

#On demande à l'utilisateur s'il veut installer linux en statique
echo -n "Installation de linux statique [y-N] ? "
read REP
#Si oui alors on procède à l'installation
if [ "$REP" == "y" ]
then
	echo -n "Installation de linux"
	VMLINUZ=$(ls /boot | grep "vmlinuz" | tail -n 1) #On réccupère le nom du vmlinuz
	INITRD=$(ls /boot | grep "initrd" | tail -n 1) #On réccupère le nom du initrd
	#On copie ces fichiers dans le dossier boot de la clé
	cp /boot/$VMLINUZ $CLE/boot/vmlinuz
	cp /boot/$INITRD $CLE/boot/initrd
	#On configure le grub grace à un fichier pré-écrit.
	cp $LEMB/data/grub-static.cfg $CLE/boot/grub/grub.cfg
	echo -n "ENTREE pour continuer"
	read PAUSE
	#On quitte l'application
	exit 0
fi
clear

#On demande à l'utilisateur s'il veut installer linux en dynamique
echo -n "Installation de linux dynamique [Y-n] ? "
read REP
#Si oui alors on procède à l'installation
if [ "$REP" == "n" ]
then
	#On quitte l'application
	exit 0	
fi

#On créer les dossiers nécessaire à l'installation
mkdir $CLE/dev $CLE/etc $CLE/proc $CLE/sys $CLE/lib $CLE/lib64+

#On copie le noyau linux dans boot
echo -n "Copie des fichier "
cp $LEMB/build/linux-4.18.9/arch/x86/boot/bzImage $CLE/boot/bzImage
#On configure le grub grace à un fichier pré-écrit.
cp $LEMB/data/grub-dynamic.cfg $CLE/boot/grub/grub.cfg

echo -n "ENTREE pour continuer"
read PAUSE

#On demande à l'utilisateur s'il veut installer busybox
echo -n "Installation de busybox dynamique(D) ou statique(s) [D-s] ? "
read REP
#Si oui alors on procède à l'installation
if [ "$REP" == "s" ]
then
	echo -n "Installation de busybox statique"
	cp $LEMB/data/config-bb-static $LEMB/build/busybox-1.29.3/.config #On prend le fichier de configuration approprié
	cd $LEMB/build/busybox-1.29.3
	make CONFIG_PREFIX=$CLE install
	cd $CLE/dev

	echo -n "MAKEDEV "
	/sbin/MAKEDEV generic console #Nécessite apt-get install makedev
else
	echo -n "Installation de busybox dynamique"
	cp $LEMB/data/config-bb-dynamic $LEMB/build/busybox-1.29.3/.config #On prend le fichier de configuration approprié
	cd $LEMB/build/busybox-1.29.3
	make CONFIG_PREFIX=$CLE install
	cd $CLE/dev

	echo -n "MAKEDEV (peut prendre un moment)"
	/sbin/MAKEDEV generic console #Nécessite apt-get install makedev
	
	echo -n "Copie des librairies"
	#Installation des librairies
	cd $LEMB/data
	ldd $CLE/bin/busybox | grep /lib > lib.txt
	cut -f2 lib.txt > lib2.txt
	cut -d'/' -f2,3,4 lib2.txt > lib.txt
	cut -d'(' -f1 lib.txt > lib2.txt
	for line in $(cat lib2.txt)
	do
		LIB=$(cut -d'/' -f1 <<< $line)
		cp /$line $CLE/$LIB/
	done
fi

echo -n "ENTREE pour continuer"
read PAUSE

## Création du dossier init.d ##
mkdir $CLE/etc/init.d

## On copie le rcS préconfiguré ##
cp $LEMB/data/rcS $CLE/etc/init.d
chmod +x $CLE/etc/init.d/rcS

## On copie le fstab préconfiguré ##
cp $LEMB/data/fstab $CLE/etc

## On copie le azerty.kmap ##
cp $LEMB/data/azerty.kmap $CLE/etc


################# Configuration du réseau ################

#On demande à l'utilisateur s'il veut être en DHCP ou IP FIXE
echo -n "Réseaux : Utilisation du dhcp(D) ou d'une ip fixe(f) [D-f] ?"
read REP
if [ "$REP" == "f" ]
then
	echo -n "Sasissez l'adresse IP : "
	read REP
	cd /lib/modules/
	mkdir $CLE/lib/modules
	cp -a -r -f * $CLE/lib/modules #Modification par rapport à busybox in a nutshell car la version n'est pas la même
	cp /etc/modprobe.conf $CLE/etc
	echo "#Configuration du réseau" >> $CLE/etc/init.d/rcS
	echo "ifconfig lo 127.0.0.1" >> $CLE/etc/init.d/rcS
	echo "ifconfig eth0 $REP" >> $CLE/etc/init.d/rcS
else
	cd $LEMB/build/busybox-1.29.3/examples/udhcp
	mkdir -p $CLE/usr/share/udhcpc
	cp simple.script $CLE/usr/share/udhcpc/default.script
	chmod +x $CLE/usr/share/udhcpc/default.script
	echo "#Configuration du réseau" >> $CLE/etc/init.d/rcS
	echo "udhcpc" >> $CLE/etc/init.d/rcS
fi 

############## Configuration des utilisateurs #############

cp $LEMB/build/busybox-1.29.3/examples/inittab $CLE/etc
cp $LEMB/data/passwd $CLE/etc
cp $LEMB/data/group $CLE/etc

