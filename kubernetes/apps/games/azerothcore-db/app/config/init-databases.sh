#!/usr/bin/env bash
# Sourced (not executed) by the mysql image entrypoint on FIRST datadir
# initialization only — a populated PVC skips it entirely, so credential or
# database changes after first boot must be applied by hand.
# ${ACORE_PASSWORD} is injected via the pod env from azerothcore-db-secret.
# docker_process_sql is an entrypoint helper; a failure aborts initialization
# (the pod crash-loops rather than starting half-initialized).

echo "[init-databases] creating the four acore databases and the acore user"
docker_process_sql <<-EOSQL
	CREATE DATABASE IF NOT EXISTS \`acore_auth\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
	CREATE DATABASE IF NOT EXISTS \`acore_characters\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
	CREATE DATABASE IF NOT EXISTS \`acore_playerbots\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
	CREATE DATABASE IF NOT EXISTS \`acore_world\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
	CREATE USER IF NOT EXISTS 'acore'@'%' IDENTIFIED BY '${ACORE_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`acore\_%\`.* TO 'acore'@'%';
	FLUSH PRIVILEGES;
EOSQL
echo "[init-databases] done"
