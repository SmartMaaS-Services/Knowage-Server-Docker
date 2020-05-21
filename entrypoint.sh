#!/bin/bash
set -e

#INIT_PROP_FILE=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/classes/it/eng/spagobi/commons/initializers/metadata/config/configs.xml
#INIT_PROP_FILE_TEMP=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/classes/it/eng/spagobi/commons/initializers/metadata/config/configs.xml.temp
SERVER_CONF=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/conf/server.xml
WEB_XML=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/web.xml
KNOWAGE_JAR=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/lib/${KNOWAGE_UTILS_VERSION}
UNZIPPED_JAR=knowageJAR
KNOWAGE_CONF=${UNZIPPED_JAR}/it/eng/spagobi/security/OAuth2/configs.properties
INITIALIZER_XML=${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/conf/config/initializers.xml

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

#change_value() {
#	touch $INIT_PROP_FILE_TEMP
#	local label="$1"
#	local value_check="$2"
#	tr -d '\n' < $INIT_PROP_FILE | sed 's#/>#/>\n#g' | sed 's/valueCheck=/\x00/g' | sed -E "s#(label=\"${label}\"[^\x00]*\x00)\"[^\"]*#\1\"${value_check}#g" | sed 's/\x00/valueCheck=/g' > $INIT_PROP_FILE_TEMP && mv $INIT_PROP_FILE_TEMP $INIT_PROP_FILE
#}

file_env "DB_USER"
file_env "DB_PASS"
file_env "DB_DB"
file_env "DB_HOST"
file_env "DB_PORT"
file_env "HMAC_KEY"
file_env "PUBLIC_ADDRESS"

#Following the tutorial https://knowage.readthedocs.io/en/latest/admin/README/index.html#configuration-with-the-idm-keyrock
if [[ -n "$KEYROCK" ]]; then
# TODO - Knowage "configuration management" needs to be automated; This will save additional overhead of IDM integration
#	change_value "SPAGOBI_SSO.ACTIVE" "true"
#	change_value "SPAGOBI.SECURITY.PORTAL-SECURITY-CLASS.className" "it.eng.spagobi.security.OAuth2SecurityInfoProvider"
#	change_value "SPAGOBI.SECURITY.USER-PROFILE-FACTORY-CLASS.className" "it.eng.spagobi.security.OAuth2SecurityServiceSupplier"
#	change_value "SPAGOBI_SSO.SECURITY_LOGOUT_URL" "${LOGOUT_URL}"

	sed -i "s|it.eng.spagobi.services.common.JWTSsoService|it.eng.spagobi.services.oauth2.Oauth2SsoService|g" $SERVER_CONF
	sed -i "s|<!-- START OAUTH 2|<!-- START OAUTH 2 -->|g" $WEB_XML && sed -i "s|END OAUTH 2 -->|<!-- END OAUTH 2 -->|g" $WEB_XML
	sed -i "s|http://192.168.28.183:8080|${SERVER_NAME}|g" $WEB_XML
	sed -i "s|it.eng.spagobi.commons.initializers.metadata.MetadataInitializer|it.eng.spagobi.commons.initializers.metadata.OAuth2MetadataInitializer|g" $INITIALIZER_XML

	unzip $KNOWAGE_JAR -d $UNZIPPED_JAR
	sed -i "s|CLIENT_ID.*|CLIENT_ID=${KEYROCK_CLIENT_ID}|g" $KNOWAGE_CONF
	sed -i "s|SECRET.*|SECRET=${KEYROCK_SECRET}|g" $KNOWAGE_CONF
	sed -i "s|AUTHORIZE_URL.*|AUTHORIZE_URL=${KEYROCK_AUTH_URL}|g" $KNOWAGE_CONF
	sed -i "s|ACCESS_TOKEN_URL.*|ACCESS_TOKEN_URL=${KEYROCK_TOKEN_URL}|g" $KNOWAGE_CONF
	sed -i "s|USER_INFO_URL.*|USER_INFO_URL=${KEYROCK_USER_URL}|g" $KNOWAGE_CONF
	sed -i "s|REDIRECT_URI.*|REDIRECT_URI=${KEYROCK_REDIRECT_URI}|g" $KNOWAGE_CONF
	sed -i "s|REST_BASE_URL.*|REST_BASE_URL=${KEYROCK_REST_URL}|g" $KNOWAGE_CONF
	sed -i "s|TOKEN_PATH.*|TOKEN_PATH=${KEYROCK_TOKEN_PATH}|g" $KNOWAGE_CONF
	sed -i "s|ROLES_PATH.*|ROLES_PATH=${KEYROCK_ROLES_PATH}|g" $KNOWAGE_CONF
	sed -i "s|ORGANIZATION_INFO_PATH.*|ORGANIZATION_INFO_PATH=${KEYROCK_ORG_INFO_PATH}|g" $KNOWAGE_CONF
	sed -i "s|APPLICATION_ID.*|APPLICATION_ID=${KEYROCK_APPLICATION_ID}|g" $KNOWAGE_CONF
	sed -i "s|ADMIN_ID.*|ADMIN_ID=${KEYROCK_ADMIN_ID}|g" $KNOWAGE_CONF
	sed -i "s|ADMIN_EMAIL.*|ADMIN_EMAIL=${KEYROCK_ADMIN_EMAIL}|g" $KNOWAGE_CONF
	sed -i "s|ADMIN_PASSWORD.*|ADMIN_PASSWORD=${KEYROCK_ADMIN_PASSWORD}|g" $KNOWAGE_CONF
	sed -i '${s/$/\nSTATE=true/}' $KNOWAGE_CONF
	cd $UNZIPPED_JAR; zip -r $KNOWAGE_JAR *
	rm -rf $UNZIPPED_JAR
	cd ..
fi

if [[ -z "$PUBLIC_ADDRESS" ]]; then
        #get the address of container
        #example : default via 172.17.42.1 dev eth0 172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.109
        PUBLIC_ADDRESS=`ip route | grep src | awk '{print $9}'`
fi

#replace the address of container inside server.xml
sed -i "s|http:\/\/.*:8080|http:\/\/${PUBLIC_ADDRESS}:8080|g" ${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/conf/server.xml
sed -i "s|http:\/\/.*:8080\/knowage|http:\/\/localhost:8080\/knowage|g" ${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/conf/server.xml
sed -i "s|http:\/\/localhost:8080|http:\/\/${PUBLIC_ADDRESS}:8080|g" ${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/webapps/knowage/WEB-INF/web.xml

#wait for MySql
./wait-for-it.sh ${DB_HOST}:${DB_PORT} -- echo "MySql is up!"

#insert knowage metadata into db if it doesn't exist
result=`mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASS} ${DB_DB} -e "SHOW TABLES LIKE '%SBI_%';"`
if [ -z "$result" ]; then
	mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASS} ${DB_DB} --execute="source ${MYSQL_SCRIPT_DIRECTORY}/MySQL_create.sql"
        mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASS} ${DB_DB} --execute="source ${MYSQL_SCRIPT_DIRECTORY}/MySQL_create_quartz_schema.sql"
fi

#replace in server.xml
old_connection='url="jdbc:mysql://localhost:3306/knowagedb" username="knowageuser" password="knowagepassword"'
new_connection='url="jdbc:mysql://'${DB_HOST}':'${DB_PORT}'/'${DB_DB}'" username="'${DB_USER}'" password="'${DB_PASS}'"'
sed -i "s|${old_connection}|${new_connection}|" ${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/conf/server.xml

#generate random HMAC key
sed -i "s|__HMAC-key__|${HMAC_KEY}|" ${KNOWAGE_DIRECTORY}/${APACHE_TOMCAT_PACKAGE}/conf/server.xml

exec "$@"
