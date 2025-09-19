FROM curlimages/curl AS downloader
RUN curl -Lo /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar


FROM eclipse-temurin:21-jdk-alpine AS extractor
WORKDIR /JavaPrograms

# Extract CTP from the installer jar (avoiding GUI)
COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh


FROM eclipse-temurin:21-jre-alpine
WORKDIR /JavaPrograms


# Copy extracted CTP files
COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP


WORKDIR /JavaPrograms/CTP

# Expose the default CTP port
EXPOSE 80

# Start CTP using Runner.jar
ENTRYPOINT ["java", "-jar", "Runner.jar"]
