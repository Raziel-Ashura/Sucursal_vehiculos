pipeline {
    agent any

    tools {
        maven 'M3'
        jdk 'JDK21'
    }

    environment {
        IMAGE_NAME = 'imagen_vehiculos'
        CONTAINER_NAME = 'contenedor_sucursal'
        APP_PORT = '9090'
        CONTAINER_PORT = '8080'
        APP_CONTEXT = 'vehiculosBuild'
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
                    string(credentialsId: 'DB_URL', variable: 'SPRING_DATASOURCE_URL'),
                    string(credentialsId: 'DB_USER', variable: 'SPRING_DATASOURCE_USERNAME'),
                    string(credentialsId: 'DB_PASS', variable: 'SPRING_DATASOURCE_PASSWORD')
                ]) {
                    sh '''
                        set +x

                        echo "Validando credenciales y conexión a Amazon RDS MySQL..."

                        if ! command -v mysql >/dev/null 2>&1; then
                            echo "ERROR: El cliente mysql no está instalado."
                            exit 1
                        fi

                        case "$SPRING_DATASOURCE_URL" in
                          jdbc:mysql://*) ;;
                          *)
                            echo "ERROR: URL JDBC inválida."
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

                        MYSQL_PWD="$SPRING_DATASOURCE_PASSWORD" mysql \
                            --protocol=TCP \
                            --connect-timeout=10 \
                            -h "$MYSQL_HOST" \
                            -P "$MYSQL_PORT" \
                            -u "$SPRING_DATASOURCE_USERNAME" \
                            "$MYSQL_DATABASE" \
                            -e "SELECT 'Conexion OK';"

                        echo "Conexión RDS validada correctamente."
                    '''
                }
            }
        }

        stage('Build WAR Artifact') {
            steps {
                sh '''
                    echo "Compilando aplicación..."
                    mvn clean package -DskipTests

                    echo "WAR generado:"
                    ls -lh target/*.war
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Construyendo imagen Docker..."
                    docker build -t "$IMAGE_NAME" .
                '''
            }
        }

        stage('Deploy Application Container') {
            steps {
                withCredentials([
                    string(credentialsId: 'DB_URL', variable: 'ENV_DB_URL'),
                    string(credentialsId: 'DB_USER', variable: 'ENV_DB_USER'),
                    string(credentialsId: 'DB_PASS', variable: 'ENV_DB_PASS')
                ]) {
                    sh '''
                        set +x

                        echo "Deteniendo contenedor anterior..."
                        docker stop "$CONTAINER_NAME" || true
                        docker rm "$CONTAINER_NAME" || true

                        echo "Iniciando contenedor..."

                        docker run -d \
                          -p "$APP_PORT:$CONTAINER_PORT" \
                          --name "$CONTAINER_NAME" \
                          -e DB_URL="$ENV_DB_URL" \
                          -e DB_USER="$ENV_DB_USER" \
                          -e DB_PASS="$ENV_DB_PASS" \
                          "$IMAGE_NAME"
                    '''
                }
            }
        }

        stage('Inspect Container Logs') {
            steps {
                sh '''
                    echo "Esperando inicio de Tomcat..."
                    sleep 30

                    echo ""
                    echo "Contenedor:"
                    docker ps --filter "name=$CONTAINER_NAME"

                    echo ""
                    echo "Últimos logs:"
                    docker logs --tail=100 "$CONTAINER_NAME"
                '''
            }
        }

        stage('Verify Application Availability') {
            steps {
                sh '''
                    echo "Esperando 10 segundos adicionales..."
                    sleep 10

                    echo "===== Verificando OpenAPI ====="
                    curl -i "http://localhost:$APP_PORT/$APP_CONTEXT/v3/api-docs"

                    echo ""
                    echo "===== Verificando endpoint /vehiculos ====="
                    curl -i "http://localhost:$APP_PORT/$APP_CONTEXT/vehiculos"
                '''
            }
        }

        stage('Run API Smoke Tests') {
            steps {
                sh '''
                    STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
                        "http://localhost:$APP_PORT/$APP_CONTEXT/vehiculos")

                    echo "HTTP Status: $STATUS"

                    if [ "$STATUS" != "200" ]; then
                        echo "La API respondió con un código diferente de 200."
                        exit 1
                    fi

                    echo "Smoke tests OK."
                '''
            }
        }
    }
}

