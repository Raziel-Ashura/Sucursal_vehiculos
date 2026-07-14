pipeline {
    agent any

    tools {
        maven 'M3'
    }

    environment {
        IMAGE_NAME = 'imagen_vehiculos'
        CONTAINER_NAME = 'contenedor_sucursal'
        APP_PORT = '9090'
        CONTAINER_PORT = '8080'
        APP_CONTEXT_PATH = 'vehiculosBuild'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                checkout scmGit(
                    branches: [[name: '*/main']],
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://github.com/Raziel-Ashura/Sucursal_vehiculos.git'
                    ]]
                )
            }
        }

        stage('Validate RDS MySQL Credentials') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'dev-rds-mysql-sucursal-jdbc-url',
                        variable: 'SPRING_DATASOURCE_URL'
                    ),
                    usernamePassword(
                        credentialsId: 'dev-rds-mysql-sucursal-credentials',
                        usernameVariable: 'SPRING_DATASOURCE_USERNAME',
                        passwordVariable: 'SPRING_DATASOURCE_PASSWORD'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "Validando credenciales y conexión a Amazon RDS MySQL..."

                        if ! command -v mysql >/dev/null 2>&1; then
                          echo "ERROR: El cliente mysql no está instalado en el servidor Jenkins."
                          echo "Instale mysql-client o mariadb-client antes de ejecutar el pipeline."
                          exit 1
                        fi

                        case "$SPRING_DATASOURCE_URL" in
                          jdbc:mysql://*)
                            echo "Formato JDBC MySQL detectado correctamente."
                            ;;
                          *)
                            echo "ERROR: SPRING_DATASOURCE_URL no tiene formato jdbc:mysql://"
                            exit 1
                            ;;
                        esac

                        JDBC_WITHOUT_PREFIX="${SPRING_DATASOURCE_URL#jdbc:mysql://}"
                        JDBC_WITHOUT_PARAMS="${JDBC_WITHOUT_PREFIX%%\\?*}"

                        MYSQL_HOST_PORT="${JDBC_WITHOUT_PARAMS%%/*}"
                        MYSQL_DATABASE="${JDBC_WITHOUT_PARAMS#*/}"

                        MYSQL_HOST="${MYSQL_HOST_PORT%%:*}"

                        if echo "$MYSQL_HOST_PORT" | grep -q ':'; then
                          MYSQL_PORT="${MYSQL_HOST_PORT##*:}"
                        else
                          MYSQL_PORT="3306"
                        fi

                        if [ -z "$MYSQL_HOST" ]; then
                          echo "ERROR: No se pudo obtener el host de RDS desde SPRING_DATASOURCE_URL."
                          exit 1
                        fi

                        if [ -z "$MYSQL_DATABASE" ] || [ "$MYSQL_DATABASE" = "$MYSQL_HOST_PORT" ]; then
                          echo "ERROR: No se pudo obtener el nombre de la base de datos desde SPRING_DATASOURCE_URL."
                          exit 1
                        fi

                        echo "Host RDS detectado: $MYSQL_HOST"
                        echo "Puerto RDS detectado: $MYSQL_PORT"
                        echo "Base de datos detectada: $MYSQL_DATABASE"

                        echo "Probando autenticación contra Amazon RDS MySQL..."

                        MYSQL_PWD="$SPRING_DATASOURCE_PASSWORD" mysql \
                          --protocol=TCP \
                          --connect-timeout=10 \
                          -h "$MYSQL_HOST" \
                          -P "$MYSQL_PORT" \
                          -u "$SPRING_DATASOURCE_USERNAME" \
                          "$MYSQL_DATABASE" \
                          -e "SELECT 'Conexion RDS MySQL OK' AS resultado, DATABASE() AS base_datos;"

                        echo "Validación correcta: Jenkins puede conectarse a RDS MySQL con las credenciales configuradas."
                    '''
                }
            }
        }

        stage('Build WAR Artifact') {
            steps {
                sh '''
                    echo "Compilando aplicación y generando archivo WAR..."
                    mvn clean package -DskipTests

                    echo "Validando artefacto generado..."
                    ls -lh target/*.war
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Construyendo imagen Docker de la aplicación..."
                    docker build -t "$IMAGE_NAME" .
                '''
            }
        }

        stage('Deploy Application Container') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'dev-rds-mysql-sucursal-jdbc-url',
                        variable: 'SPRING_DATASOURCE_URL'
                    ),
                    usernamePassword(
                        credentialsId: 'dev-rds-mysql-sucursal-credentials',
                        usernameVariable: 'SPRING_DATASOURCE_USERNAME',
                        passwordVariable: 'SPRING_DATASOURCE_PASSWORD'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "Deteniendo contenedor anterior si existe..."
                        docker stop "$CONTAINER_NAME" || true
                        docker rm "$CONTAINER_NAME" || true

                        echo "Levantando contenedor con variables de conexión hacia Amazon RDS MySQL..."

                        docker run -d \
                          -p "$APP_PORT:$CONTAINER_PORT" \
                          --name "$CONTAINER_NAME" \
                          -e SPRING_DATASOURCE_URL="$SPRING_DATASOURCE_URL" \
                          -e SPRING_DATASOURCE_USERNAME="$SPRING_DATASOURCE_USERNAME" \
                          -e SPRING_DATASOURCE_PASSWORD="$SPRING_DATASOURCE_PASSWORD" \
                          "$IMAGE_NAME"

                        echo "Contenedor desplegado correctamente."
                    '''
                }
            }
        }

        stage('Inspect Container Logs') {
            steps {
                sh '''
                    echo "Esperando inicio de Tomcat/Spring Boot..."
                    sleep 25

                    echo "Estado del contenedor:"
                    docker ps --filter "name=$CONTAINER_NAME"

                    echo "Últimos logs del contenedor:"
                    docker logs --tail=80 "$CONTAINER_NAME"
                '''
            }
        }

        stage('Verify Application Availability') {
            steps {
                sh '''
                    echo "Validando endpoint raíz de la aplicación..."
                    curl -f -s "http://localhost:$APP_PORT/$APP_CONTEXT_PATH/" || exit 1
                '''
            }
        }

        stage('Run API Smoke Tests') {
            steps {
                sh '''
                    echo "Validando OpenAPI / Swagger..."
                    curl -f -s "http://localhost:$APP_PORT/$APP_CONTEXT_PATH/api-docs" || exit 1

                    echo "Validando endpoint GET /vehiculos..."
                    curl -f -s "http://localhost:$APP_PORT/$APP_CONTEXT_PATH/vehiculos" || exit 1

                    echo "Validaciones funcionales finalizadas correctamente."
                '''
            }
        }
    }
}
