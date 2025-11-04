FROM curlimages/curl AS downloader
RUN curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar

FROM maven:3.9-eclipse-temurin-11 AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y git && \
    git clone --depth 1 --branch jai-imageio-jpeg2000-1.2-pre-dr-b04-2014-09-13 https://github.com/jai-imageio/jai-imageio-jpeg2000.git && \
    cd jai-imageio-jpeg2000 && \
    mvn clean package -DskipTests

FROM eclipse-temurin:21-jdk-jammy AS extractor
WORKDIR /JavaPrograms

COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh && \
    rm -f /JavaPrograms/CTP/libraries/imageio/clibwrapper_jiio-*.jar

# Add the built JPEG2000 plugin that matches CTP's jai_imageio version
COPY --from=builder /build/jai-imageio-jpeg2000/target/jai-imageio-jpeg2000-1.2-pre-dr-b04-2014-09-13.jar /JavaPrograms/CTP/libraries/imageio/


FROM eclipse-temurin:21-jre-jammy
WORKDIR /JavaPrograms/CTP

COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP

EXPOSE 80

# Run with module opens and force pure-Java JPEG2000
ENTRYPOINT ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.base/java.util=ALL-UNNAMED", "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio.stream=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED", "-Djava.awt.headless=true", "-Dcom.sun.media.imageio.disableCodecLib=true", "-Dcom.sun.media.imageio.stream.buffersize=65536", "-jar", "Runner.jar"]
