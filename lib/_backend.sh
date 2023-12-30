#!/bin/bash
#
# Funções  para configurar o back-end do app
###########################################
# Criar banco Redis e Mariadb usando o Docker
# Arguments:
#   None
#######################################
backend_redis_create() {
    print_banner
    printf "${WHITE} 💻 Criando Redis & Banco MariaDB...${GRAY_LIGHT}"
    printf "\n\n"

    sleep 2

    # Adicionar o usuário deploy ao grupo docker
    usermod -aG docker deploy || { echo "Erro ao adicionar usuário ao grupo Docker"; exit 1; }

    # Executar o contêiner Redis
    docker run --name redis-${instancia_add} -p ${redis_port}:6379 --restart always --detach redis redis-server --requirepass ${mysql_root_password} || { echo "Erro ao executar contêiner Redis"; exit 1; }

    # Aguardar 2 segundos antes de continuar
    sleep 2

    # Criar banco de dados no MariaDB
     mysql -u root -p"${mysql_root_password}" -e "CREATE DATABASE ${instancia_add};" || { echo "Erro ao criar banco de dados no MariaDB"; exit 1; }

    # Criar usuário e conceder privilégios no MariaDB
    mysql -u root -p"${mysql_root_password}" -e "CREATE USER '${instancia_add}'@'%' IDENTIFIED BY '${mysql_root_password}';" || { echo "Erro ao criar usuário no MariaDB"; exit 1; }
    mysql -u root -p"${mysql_root_password}" -e "GRANT ALL PRIVILEGES ON ${instancia_add}.* TO '${instancia_add}'@'%';" || { echo "Erro ao conceder privilégios no MariaDB"; exit 1; }
    mysql -u root -p"${mysql_root_password}" -e "FLUSH PRIVILEGES;" || { echo "Erro ao executar FLUSH PRIVILEGES no MariaDB"; exit 1; }

    # Aguardar 2 segundos antes de continuar
    sleep 2
}

# Define variável de ambiente para o back-end
# Arguments:
#   None
#######################################
backend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  # Certifique-se de que as variáveis estão formatadas corretamente
  backend_url="https://${backend_url#https://}"
  frontend_url="https://${frontend_url#https://}"

  cat <<EOF > /home/deploy/${instancia_add}/backend/.env
NODE_ENV=
BACKEND_URL=${backend_url}
FRONTEND_URL=${frontend_url}
PROXY_PORT=443
PORT=${backend_port}

DB_HOST=localhost
DB_DIALECT=mariadb
DB_USER=${instancia_add}
DB_PASS=${mysql_root_password}
DB_NAME=${instancia_add}
DB_PORT=3306

JWT_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_refresh_secret}

REDIS_URI=redis://:${mysql_root_password}@127.0.0.1:${redis_port}
REDIS_OPT_LIMITER_MAX=1
REGIS_OPT_LIMITER_DURATION=3000

USER_LIMIT=${max_user}
CONNECTIONS_LIMIT=${max_whats}
CLOSED_SEND_BY_ME=true

GERENCIANET_SANDBOX=false
GERENCIANET_CLIENT_ID=sua-id
GERENCIANET_CLIENT_SECRET=sua_chave_secreta
GERENCIANET_PIX_CERT=nome_do_certificado
GERENCIANET_PIX_KEY=chave_pix_gerencianet
EOF
}
#######################################
# Instala as dependências do Node.js
# Arguments:
#   none
#######################################
backend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${instancia_add}/backend" ]; then
    cd "/home/deploy/${instancia_add}/backend" || exit 1

    # Instala as dependências usando npm
    yarn install || exit 1
  else
    echo "O diretório /home/deploy/${instancia_add}/backend não existe."
    exit 1
  fi

  sleep 2
}
#######################################
# Compila o código do backend
# Argumentos:
#   Nenhum
#######################################
backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${instancia_add}/backend" ]; then
    cd "/home/deploy/${instancia_add}/backend" || exit 1

    # Compila o código usando yarn
    yarn build || exit 1
  else
    echo "O diretório /home/deploy/${instancia_add}/backend não existe."
    exit 1
  fi

  sleep 2
}

#######################################
# Atualiza o backend
# Argumentos:
#   Nenhum
#######################################
backend_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando o backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${empresa_atualizar}" ]; then
    cd "/home/deploy/${empresa_atualizar}" || exit 1

    # Para o processo PM2
    pm2 stop ${empresa_atualizar}-backend || true

    # Atualiza o código-fonte do backend
    git pull || exit 1

    # Muda para o diretório do backend
    cd "/home/deploy/${empresa_atualizar}/backend" || exit 1

    # Instala dependências usando yarn
    yarn install || exit 1
    yarn upgrade --force || exit 1

    # Remove o diretório dist
    rm -rf dist

    # Compila o código
    yarn build || exit 1

    # Executa as migrações do banco de dados
    npx sequelize db:migrate || exit 1

    # Executa as sementes do banco de dados
    npx sequelize db:seed || exit 1

    # Inicia o processo PM2
    pm2 start ${empresa_atualizar}-backend || exit 1

    # Salva a configuração do PM2
    pm2 save
  else
    echo "O diretório /home/deploy/${empresa_atualizar} não existe."
    exit 1
  fi

  sleep 2
}
#######################################
# Executa db:migrate
# Argumentos:
#   Nenhum
#######################################
backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${instancia_add}/backend" ]; then
    cd "/home/deploy/${instancia_add}/backend" || exit 1

    # Executa a migração do banco de dados usando npx sequelize
    npx sequelize db:migrate || exit 1
  else
    echo "O diretório /home/deploy/${instancia_add}/backend não existe."
    exit 1
  fi

  sleep 2
}

#######################################
# Executa db:seed
# Argumentos:
#   Nenhum
#######################################
backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${instancia_add}/backend" ]; then
    cd "/home/deploy/${instancia_add}/backend" || exit 1

    # Executa a semente do banco de dados usando npx sequelize
    npx sequelize db:seed:all || exit 1
  else
    echo "O diretório /home/deploy/${instancia_add}/backend não existe."
    exit 1
  fi

  sleep 2
}

#######################################
# Inicia o backend usando pm2 em modo
# de produção.
# Argumentos:
#   Nenhum
#######################################
backend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/home/deploy/${instancia_add}/backend" ]; then
    cd "/home/deploy/${instancia_add}/backend" || exit 1

    # Inicia o processo PM2 usando o script server.js
    pm2 start dist/server.js --name ${instancia_add}-backend || exit 1
  else
    echo "O diretório /home/deploy/${instancia_add}/backend não existe."
    exit 1
  fi

  sleep 2
}
#######################################
# Configura o Nginx para o backend
# Argumentos:
#   Nenhum
#######################################
backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  backend_hostname="${backend_url#https://}"

  # Certifica-se de que o diretório existe antes de mudar para ele
  if [ -d "/etc/nginx/sites-available" ]; then
    cat <<EOF > "/etc/nginx/sites-available/${instancia_add}-backend"
server {
  server_name $backend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF

    ln -s "/etc/nginx/sites-available/${instancia_add}-backend" "/etc/nginx/sites-enabled/${instancia_add}-backend"
  else
    echo "O diretório /etc/nginx/sites-available não existe."
    exit 1
  fi

  sleep 2
}