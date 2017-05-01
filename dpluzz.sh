#!/bin/bash
#===============================================================================
# dpluzz: a FranceTV Pluzz downloader
#
# author: 
# Marc B.R. Joos <marc.joos@gmail.com>
# Contribut:
# Nicolou  <nicolasMontarnal29@gmail.com>
#
# copyrights:
# Copyrights 2016, Marc Joos
# This file is distributed under GNU/GPL license, 
# see <http://www.gnu.org/licenses/>.
#
# date:
# created:       01-21-2016
# last modified: 01-05-2017
#===============================================================================

#some appli setting
# where we download temp file
TPD=/tmp/dpluzz


usage="$(basename "$0") [-h] [-v] [-f fichier] [-r resolution] -- recupere des videos depuis FranceTV Pluzz

usage :
    -h  aide
    -f  URL de la page HTML de la video a telecharger
    -r resolution ('high', 'medium', 'low', 'shameful') défaut : 'high'
    -v verbose on	

exemple :
    ./$(basename "$0") -f http://pluzz.francetv.fr/videos/pieces_a_conviction.html"

if [[ $# -eq 0 ]] ; then
       echo "$usage" >&2
       exit 1
fi

while getopts ':hf:r:v' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    f) fichier=$OPTARG
       ;;
    r) resolution=$OPTARG
       ;;
    d) VERB=1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done

if [ -z $fichier ]; then
       echo "$usage" >&2
       exit 
fi


if [ -z $resolution ]; then
    resolution="high"
fi
if [ "$resolution" = "high" ]; then
    res=3
fi
if [ "$resolution" = "medium" ]; then
    res=2
fi
if [ "$resolution" = "low" ]; then
    res=1
fi
if [ "$resolution" = "shameful" ]; then
    res=0
fi

if [ -n $VERB ] ; then echo -e "\033[32m Résolution choisie : $resolution , res=$res  \033[0m"; fi

#suppression du repertoire temp et re-creation
rm -r $TPD
mkdir -p $TPD

# Récupérer le code source de la page
wget -q -O $TPD/scr.html $fichier

# Récupérer l'ID de la vidéo à télécharger
ID=`grep -oP "image/.*emissions/(\d+)" $TPD/scr.html | grep -oP "\d+" | tail -1`

if [ -n $VERB ] ; then echo -e "\033[32m l'identifiant de l'emission est $ID \033[0m"; fi


# Version alternative en utilisant des listes
# lID=($ID)
# ID=${lID[0]}

# Récupérer le JSON contenant les infos de la vidéo dont la liste de lecture
wget -q -O $TPD/jsonfile.json http://webservices.francetelevisions.fr/tools/getInfosOeuvre/v2/?idDiffusion=$ID\&catalogue=Pluzz

# Trouver la liste de lecture dans le JSON
master=$(grep -oP "http:\\\/\\\/repl[^\"]*master\.m3u8" $TPD/jsonfile.json | tail -1)
# Enlève les backslashes
master=$(echo $master | sed 's/\\//g')

if [ -n $VERB ] ; then echo -e "\033[32m recuperation du fichier json de liste de lecture $TPD/jsonfile.json \n master=$master \033[0m"; fi


# Récupérer la liste de lecture
wget -q -O $TPD/master.m3u8 $master
# Récupérer la liste de lecture à la résolution désirée
index=$(grep -P "index_"$res"_av" $TPD/master.m3u8)
if [ -n $VERB ] ; then echo -e "\033[32m recuperation pour la résolution $res : $index \033[0m"; fi

wget -q -O $TPD/lstRes.txt $index


if [ -n $VERB ] ; then echo -e "\033[32m Liste des fichiers à récupérer dans $ $TPD/lstRes.txt  \033[0m"; fi
NBF=$(cat $TPD/lstRes.txt | grep http | wc -l)
if [ -n $VERB ] ; then echo -e "\033[32m     nbr de fichiers : $NBF  \n  \033[0m"; fi

# Récupérer ls parties de la vidéo
i=1
for f in $(cat $TPD/lstRes.txt | grep http); do
	echo -n " `printf %03d ${i}`.ts  "
	wget -q -O $TPD/`printf %03d ${i}`.ts $f
	i=$(($i+1));
done  
echo ""


# Merger les fichiers
for i in $(ls $TPD/*ts); do cat $i >> video_$ID.ts; done

