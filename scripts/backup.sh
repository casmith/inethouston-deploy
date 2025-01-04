rm -rf backup-temp/*
docker run --rm -v ./backup-temp:/mysqldump -e DB_USER='beoftexas' -e DB_NAME=beoftexas -e DB_PASS=$(cat beoftexas_db_pw.txt) -e DB_HOST=work_db_1 --network work_default casmith/mysqldump
cp backup-temp/*.* backup-temp/beoftexas_latest.sql.gz
for filename in ./backup-temp/*.sql.gz; do aws s3 cp $filename s3://beoftexas-backup/$(basename $filename); done
