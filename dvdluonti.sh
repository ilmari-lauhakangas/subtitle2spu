#!/usr/bin/env bash
# Tarvitaan ohjelmat zenity, imagemagick, ffmpeg, dvdauthor (sisältää spumux-ohjelman) ja skripti subtitle2spu
set -o errexit
set -o nounset
set -o pipefail
video="$(zenity --title "Video" --file-selection)"
if [[ "$video" == 0 ]]; then
    exit
fi
kuvateksti="$(zenity --title "Kuvateksti" --file-selection)"
if [[ "$kuvateksti" == 0 ]]; then
    exit
fi
tallennushakemisto="$(zenity --title "Hakemisto tallennusta varten" --file-selection --directory)"
if [[ "$kuvateksti" == 0 ]]; then
    exit
fi

nimi="$(basename "${video%.*}")"

mkdir -p "/tmp/$nimi"

ffmpeg -i "$video" -target pal-dvd "/tmp/$nimi/$nimi.mpg"

# DVD-standardissa on määritelty kuvateksteille vain neljä väriä, joista käsittääkseni yhden täytyy
# olla läpinäkyvyys. Kaikkialla puhutaan kuudentoista värin paletista, joista nämä neljä pitää valita, mutten löytänyt
# mitään virallista dokumenttia kyseistä paletista. Tässä viestissä luetellaan värit, joita kuulemma
# pitää käyttää spumuxin kanssa: https://video.stackexchange.com/questions/37007/dvdauthor-spumux-aborted-picture-had-256-colors
# Tarkalleen sama paletti täytyy antaa dvdauthorille.
# DVD:n kuvatekstit eivät ikinä voi näyttää kovin hyviltä rajallisen paletin kanssa. Valkoinen tausta, musta reunus ja yksi harmaan
# sävy hieman pehmentämässä reunoja.
# subtitle2spu-skriptiin tein muutoksen, jossa kuvatekstikuvien XML-tiedostossa määritellään tietyn värin olevan läpinäkyvä.
# Valitsin väriksi harmaan, 808080 heksa-arvona. subtitle2spu luo myös kuvat siten, että 808080 on taustaväri.

# Luodaan paletti PGM-muodossa https://en.wikipedia.org/wiki/Netpbm#File_formats
cat << EOF > /tmp/palette.pgm
P2
4 1
255
255 0 128 192
EOF

# Luodaan sama paletti dvdauthorin ymmärtämässä muodossa, heksoina
cat << EOF > /tmp/palette.rgb
000000
ffffff
808080
C0C0C0
EOF

# Muunnetaan PGM-paletti PNG-muotoon, jota käytetään subtitle2spu-skriptissä olevassa Imagemagick-komennossa
magick /tmp/palette.pgm /tmp/palette.png

# subtitle2spu-skripti luo jokaisesta kuvatekstistä oman PNG-kuvan sekä XML-tiedoston, jossa määritellään kuvien aikaleimat.
# Saatavilla olevat fontit voi nähdä sanomalla magick -list font
./subtitle2spu.py --font=Bitstream-Vera-Sans-Bold -o "/tmp/$nimi/$nimi.xml" "$kuvateksti"

# spumux käyttää subtitle2spu:n luomaa XML-tiedostoa ja luo MPEG2-videon
VIDEO_FORMAT="PAL" spumux -s1 "/tmp/$nimi/$nimi.xml" < "/tmp/$nimi/$nimi.mpg" > "/tmp/$nimi/${nimi}_subs.mpg"

# Luodaan dvdauthorille määrittely, joka sisältää kuvatekstien väripaletin
cat << EOF > "/tmp/$nimi/auth.xml"
<dvdauthor>
    <vmgm />
    <titleset>
        <titles>
            <subpicture lang="fi"/>
            <pgc palette="/tmp/palette.rgb">
                <vob file="/tmp/$nimi/${nimi}_subs.mpg" />
            </pgc>
        </titles>
    </titleset>
</dvdauthor>
EOF

VIDEO_FORMAT="PAL" dvdauthor -o "$tallennushakemisto" -x "/tmp/$nimi/auth.xml"
