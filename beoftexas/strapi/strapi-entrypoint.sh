export DATABASE_PASSWORD=$(cat /run/secrets/strapi_db_pw) 

source /usr/local/bin/docker-entrypoint.sh