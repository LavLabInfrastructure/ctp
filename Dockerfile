FROM curlimages/curl AS downloader
RUN curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar && \
    curl -fL -o /tmp/jai-imageio-core.jar https://repo1.maven.org/maven2/com/github/jai-imageio/jai-imageio-core/1.4.0/jai-imageio-core-1.4.0.jar && \
    curl -fL -o /tmp/jai-imageio-jpeg2000.jar https://repo1.maven.org/maven2/com/github/jai-imageio/jai-imageio-jpeg2000/1.4.0/jai-imageio-jpeg2000-1.4.0.jar


FROM eclipse-temurin:21-jdk-alpine AS extractor
WORKDIR /JavaPrograms

# Extract CTP from the installer jar (avoiding GUI)
COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh

# Add JPEG 2000 (JP2/J2K) ImageIO support for Java
# These pure-Java plugins enable JPEG 2000 decoding used by DICOM.
COPY --from=downloader /tmp/jai-imageio-core.jar /JavaPrograms/CTP/lib/jai-imageio-core.jar
COPY --from=downloader /tmp/jai-imageio-jpeg2000.jar /JavaPrograms/CTP/lib/jai-imageio-jpeg2000.jar


FROM eclipse-temurin:21-jre-alpine
WORKDIR /JavaPrograms


# Copy extracted CTP files
COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP


WORKDIR /JavaPrograms/CTP

# Expose the default CTP port
EXPOSE 80

# Start CTP using Runner.jar
ENTRYPOINT ["java", "-jar", "Runner.jar"]
