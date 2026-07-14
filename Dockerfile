FROM tomcat:10.1.23-jre21
LABEL maintainer="Raziel"
EXPOSE 8080
COPY target/*.war /usr/local/tomcat/webapps/vehiculosBuild.war
