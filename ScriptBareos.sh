#!/bin/bash

BAREOS_DIR="/etc/bareos/bareos-dir.d"
STORAGE_FILE="$BAREOS_DIR/storage/File.conf"

# Função para criar um Fileset
criar_fileset() {
    echo "Criando um novo Fileset..."
    echo "Informe o nome do Fileset:"
    read fileset_name
    echo "Informe a descrição do Fileset:"
    read description
    echo "Informe o caminho do diretório a ser incluído:"
    read dir_path

    cat <<EOL > $BAREOS_DIR/fileset/$fileset_name.conf
FileSet {
  Name = "$fileset_name"
  Description = "$description"
  Include {
    Options {
      Signature = MD5
      Compression = GZIP6
    }
    File = $dir_path
  }
}
EOL

    echo "Fileset $fileset_name criado com sucesso."
}

# Função para criar um Schedule
criar_schedule() {
    echo "Criando um novo Schedule..."
    echo "Informe o nome do Schedule:"
    read schedule_name
    echo "Informe o comando Run (ex: 'Full 1st-5th sun at 01:00'):"
    read run_command

    cat <<EOL > $BAREOS_DIR/schedule/$schedule_name.conf
Schedule {
  Name = "$schedule_name"
  Run = $run_command
}
EOL

    echo "Schedule $schedule_name criado com sucesso."
}

# Função para listar Storages dentro do arquivo de Storage
listar_storages() {
    storages=($(grep -oP 'Name\s*=\s*\K\S+' $STORAGE_FILE))
    for i in "${!storages[@]}"; do
        echo "$((i+1))) ${storages[$i]}"
    done
}

# Função para listar arquivos de um diretório
listar_arquivos() {
    dir=$1
    arquivos=($(ls $dir))
    for i in "${!arquivos[@]}"; do
        echo "$((i+1))) ${arquivos[$i]}"
    done
}

# Função para criar um Job e um JobDefs
criar_job() {
    echo "Criando um novo Job..."
    echo "Informe o nome do Job:"
    read job_name

    echo "Selecione o tipo de backup:"
    tipos=("Full" "Incremental" "Differential")
    for i in "${!tipos[@]}"; do
        echo "$((i+1))) ${tipos[$i]}"
    done
    read tipo_index
    backup_type=${tipos[$tipo_index-1]}

    echo "Selecione o cliente:"
    listar_arquivos "$BAREOS_DIR/client"
    read client_index
    client_name=$(ls $BAREOS_DIR/client | sed -n "${client_index}p" | sed 's/.conf//')

    echo "Selecione o Schedule:"
    listar_arquivos "$BAREOS_DIR/schedule"
    echo "$(( ${#arquivos[@]}+1 )) Criar novo Schedule"
    read schedule_index
    if [ $schedule_index -eq $(( ${#arquivos[@]}+1 )) ]; then
        criar_schedule
        listar_arquivos "$BAREOS_DIR/schedule"
        read schedule_index
    fi
    schedule_name=$(ls $BAREOS_DIR/schedule | sed -n "${schedule_index}p" | sed 's/.conf//')

    echo "Selecione o Storage:"
    listar_storages
    read storage_index
    storage_name=${storages[$storage_index-1]}

    echo "Selecione a Pool:"
    listar_arquivos "$BAREOS_DIR/pool"
    read pool_index
    pool_name=$(ls $BAREOS_DIR/pool | sed -n "${pool_index}p" | sed 's/.conf//')

    echo "Selecione o Fileset:"
    listar_arquivos "$BAREOS_DIR/fileset"
    echo "$(( ${#arquivos[@]}+1 )) Criar novo Fileset"
    read fileset_index
    if [ $fileset_index -eq $(( ${#arquivos[@]}+1 )) ]; then
        criar_fileset
        listar_arquivos "$BAREOS_DIR/fileset"
        read fileset_index
    fi
    fileset_name=$(ls $BAREOS_DIR/fileset | sed -n "${fileset_index}p" | sed 's/.conf//')

    # Criar o arquivo JobDefs
    cat <<EOL > $BAREOS_DIR/jobdefs/$job_name.conf
JobDefs {
  Name = "$job_name"
  Type = Backup
  Level = $backup_type
  Client = $client_name
  FileSet = $fileset_name
  Schedule = $schedule_name
  Storage = $storage_name
  Pool = $pool_name
  Messages = Standard
  Priority = 10
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
  Full Backup Pool = LESTECOMPLETO
  Differential Backup Pool = LESTEDIFERENCIAL
  Incremental Backup Pool = LESTEINCREMENTAL
}
EOL

    echo "JobDefs $job_name criado com sucesso."

    # Criar o arquivo Job no diretório de Jobs
    cat <<EOL > $BAREOS_DIR/job/$job_name.conf
Job {
  Name = "$job_name"
  JobDefs = "$job_name"
  Client = $client_name
}
EOL

    echo "Job $job_name criado com sucesso no diretório de Jobs."
}

# Menu principal
menu_principal() {
    echo "Escolha uma opção:"
    echo "1) Criar novo Job"
    echo "2) Sair"
    read opcao

    case $opcao in
        1) criar_job ;;
        2) exit ;;
        *) echo "Opção inválida!" ;;
    esac
}

# Loop principal
while true; do
    menu_principal
done
