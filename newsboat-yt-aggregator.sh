#!/usr/bin/env bash

Main(){
    
    Err() {
        printf 'ERROR: %s\n' "$2" 1>&2
        sleep 2
        [ $1 -gt 0 ] && exit $1
    }

    Title() {
        #clear
        printf -v Bar '%*s' $((${#1} + 2)) ' '
        printf '%s\n║ %s ║\n%s\n' "╔${Bar// /═}╗" "$1" "╚${Bar// /═}╝"
    }

    # obtener Id y nombre del canal (max 30 caracteres)
    GetId() {
        wget -L --output-document=/tmp/tempLink "${1}" && \
        NEWID=$(grep -oE "/channel/.{0,24}" /tmp/tempLink | head -n 1 | cut -d'/' -f3) && \
        [[ $(printf '%s' "${NEWID}" | wc -c) == "24" ]] && \
        NEWNAME=$(grep -oE "\"channelName\"\:\".{0,30}" /tmp/tempLink | cut -d\" -f 4) || \
        Err 0 "URL: ${1}" 
        [[ ${NEWNAME} == '' ]] && NEWNAME=$(grep -oE "name\"\:\ \".{0,30}" /tmp/tempLink | cut -d\" -f 3)
        USERLINK='' && rm -f /tmp/tempLink
        ValidaLink "${NEWID}" "${NEWNAME}"
    }

    # verificar si NEWID existe en archivo URLS
    ValidaLink() {
        if [[ ${1} == '' ]]; then
            Err 0 'ID no obtenido, verifica el link'
        else
            if [[ ! -n $(grep ${1} ${HOME}/.config/newsboat/urls) ]]; then
                BASEURL="https://youtube.com/feeds/videos.xml?channel_id=${1}"
                AddLink "${BASEURL}" "${NEWNAME}"
            else
                #echo "${2}"
                printf '\nOmitiendo [%s], canal ya esta en la lista.\n' "${2}"
            fi
        fi
    }

    # DEBUG en /tmp/
    # agregar canal a URLS
    AddLink(){
        #printf '%s\n' "${1} \"~${2}\"" >> /tmp/urlsTemp
        printf '%s\n' "${1} \"~${2}\"" >> ${HOME}/.config/newsboat/urls
        Title "Canal agregado: ${2}" && NEWNAME='' && NEWID=''
    }

    # leer lista de urls, validar y agregar
    AddList(){
        printf 'Ruta al archivo\n'
        read -p '--> : ' LISTA
        if [[ -f $LISTA ]]; then
            while read -r line; do
                GetId "${line}"
            done < "$LISTA"
        else
            Err 0 'Archivo no encontrado'
            Main
        fi
    }

    # consulta newpipe.db
    ImportDB(){
        while read -r line; do
            NEWID=$(cut -d'|' -f1 <<< $line)
            NEWNAME=$(cut -d'|' -f2 <<< $line)
            ValidaLink "${NEWID}" "${NEWNAME}"
        done <<< "$(sqlite3 $1 'select url,name from subscriptions' |  cut -d\/ -f5)"
        rm -f /tmp/newpipe.db
    }

    # extrae newpipe-db.zip
    NewPipeDB(){
        if [[ ${RUTADB} == *\.zip ]]; then
            printf 'Unzipping %s en /tmp/ \n' "${1}"
            unzip -qq $RUTADB newpipe.db -d /tmp/ && \
            ImportDB '/tmp/newpipe.db'
        elif [[ ${RUTADB} == *\.db ]]; then
            ImportDB ${RUTADB}
        else
            Err 0 'Base de Datos no encontrada.'
            Main
        fi
    }

    ImportJSON(){
        if [[ ${RUTAJSON} == *\.json ]]; then
            while read -r line; do
                NEWID=$(cut -d' ' -f1 <<< $line)
                NEWNAME=$(cut -d' ' -f2-10 <<< $line)
                ValidaLink "${NEWID}" "${NEWNAME}"
            done <<< "$(sed 's/channel\//\n/g; s/\",\"name\":\"/ /g; s/\"//g' ${1} | tail -n +2 | sed 's/}.*$//g')"
        else
            Err 0 'Archivo JSON no encontrado.'
            Main
        fi
    }

    while :; do
        Title  'Añadir canal(es) de YouTube al feed de Newsboat'
        printf '\n\tOpciones:\n\n'
        printf '\t1) Importar desde un link\n'
        printf '\t2) Importar desde una lista de links\n'
        printf '\t3) Importar desde base de datos de NewPipe\n'
        printf '\t4) Importar desde archivo JSON de NewPipe\n'
        printf '\t0) Salir\n'
        printf '\n\t¿Que necesitas?\n'
        read -p '--> : '
        case ${REPLY} in
            '1')
                printf 'Copia y pega el link\n'
                read -p '--> : ' USERLINK
                GetId "${USERLINK}"
                exit 0
                ;;
            '2')
                AddList
                exit 0
                ;;
            '3')
                printf 'Ruta a la base de datos\n'
                read -p '--> : ' RUTADB
                NewPipeDB ${RUTADB}
                exit 0
                ;;
            '4')
                printf 'Ruta al archvo JSON\n'
                read -p '--> : ' RUTAJSON
                ImportJSON ${RUTAJSON}
                exit 0
                ;;
            '0')
                exit 0
                ;;
            '')
                Err 0 'Respuesta requerida.'
                ;;
            *)
                Err 0 'Respuesta inválida.' 
                ;;
        esac
    done
}

Main

