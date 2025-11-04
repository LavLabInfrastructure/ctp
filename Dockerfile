FROM curlimages/curl AS downloader
RUN curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar && \
    curl -fL -o /tmp/jai-imageio-core.jar https://repo1.maven.org/maven2/com/github/jai-imageio/jai-imageio-core/1.4.0/jai-imageio-core-1.4.0.jar && \
    curl -fL -o /tmp/jai-imageio-jpeg2000.jar https://repo1.maven.org/maven2/com/github/jai-imageio/jai-imageio-jpeg2000/1.4.0/jai-imageio-jpeg2000-1.4.0.jar


FROM eclipse-temurin:21-jdk-jammy AS extractor
WORKDIR /JavaPrograms

COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh

COPY --from=downloader /tmp/jai-imageio-core.jar /JavaPrograms/CTP/lib/jai-imageio-core.jar
COPY --from=downloader /tmp/jai-imageio-jpeg2000.jar /JavaPrograms/CTP/lib/jai-imageio-jpeg2000.jar


FROM eclipse-temurin:21-jre-jammy
WORKDIR /JavaPrograms

COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP


WORKDIR /JavaPrograms/CTP

EXPOSE 80

ENTRYPOINT ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.base/java.util=ALL-UNNAMED", "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio.stream=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED", "-Djava.awt.headless=true", "-Dcom.sun.media.imageio.disableCodecLib=true", "-jar", "Runner.jar"]
