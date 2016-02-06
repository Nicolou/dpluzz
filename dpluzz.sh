#!/bin/bash
#===============================================================================
# dpluzz: a FranceTV Pluzz downloader
#
# author: 
# Marc B.R. Joos <marc.joos@gmail.com>
#
# copyrights:
# Copyrights 2016, Marc Joos
# This file is distributed under GNU/GPL license, 
# see <http://www.gnu.org/licenses/>.
#
# date:
# created:       01-21-2016
# last modified: 02-06-2016
#===============================================================================

usage="$(basename "$0") [-h] [-f fichier] [-r resolution] -- recupere des videos depuis FranceTV Pluzz

usage :
    -h  aide
    -f  URL de la page HTML de la video a telecharger
    -r resolution ('high', 'medium', 'low', 'shameful') défaut : 'high'

exemple :
    ./$(basename "$0") -f http://pluzz.francetv.fr/videos/pieces_a_conviction.html"

if [[ $# -eq 0 ]] ; then
    echo "Lancer $(basename "$0") -h pour obtenir l'aide de ce script"
    exit 0
fi

while getopts ':hf:r:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    f) fichier=$OPTARG
       ;;
    r) resolution=$OPTARG
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done

if [ -n $resolution ]; then
    resolution="high"
fi
if [ $resolution -eq "high"]; then
    res=3
fi
if [ $resolution -eq "medium"]; then
    res=2
fi
if [ $resolution -eq "low"]; then
    res=1
fi
if [ $resolution -eq "shameful"]; then
    res=0
fi


# Récupérer le code source de la page
wget $fichier

# Récupérer l'ID de la vidéo à télécharger
fichier=$(basename $fichier)
ID=`grep -oP "image/.*emissions/(\d+)" $fichier | grep -oP "\d+"`
set -- $ID
ID=$1

# Version alternative en utilisant des listes
# lID=($ID)
# ID=${lID[0]}

# Récupérer le JSON contenant les infos de la vidéo dont la liste de lecture
wget http://webservices.francetelevisions.fr/tools/getInfosOeuvre/v2/?idDiffusion=$ID\&catalogue=Pluzz

# Trouver la liste de lecture dans le JSON
master=$(grep -oP "http:\\\/\\\/repl[^\"]*master\.m3u8" index.html\?idDiffusion\=$ID\&catalogue\=Pluzz)
set -- $master
master=$1
# Enlève les backslashes
master=$(echo $master | sed 's/\\//g')

# Récupérer la liste de lecture
wget $master
# Récupérer la liste de lecture à la résolution désirée
index=$(grep -P "index_"$res"_av" master.m3u8)
wget $index

# Récupérer les parties de la vidéo
more index_${res}_av.m3u8* | xargs wget

# Renommer (pour nettoyer les noms de fichiers puis pour réindexer)
rename 's/\?null=//g' *
for i in $(ls *ts); do mv $i part_`printf %03d ${i:7:-8}`.ts; done

# Merger les fichiers
for i in $(ls *ts); do cat $i >> video.ts; done

# Nettoyage
rm $fichier
rm $master
rm part_*.ts
