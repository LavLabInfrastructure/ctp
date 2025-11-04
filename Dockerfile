FROM curlimages/curl AS downloader
RUN apk add --no-cache unzip && \
    curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar && \
    curl -fL -o /tmp/imageio-ext-jars.zip https://demo.geo-solutions.it/share/github/imageio-ext/releases/1.3.X/1.3.2/imageio-ext-1.3.2-jars.zip && \
    cd /tmp && unzip -q imageio-ext-jars.zip && \
    mkdir -p /output && \
    cp /tmp/installer.jar /output/ && \
    cp /tmp/imageio-ext-1.3.2/*.jar /output/


FROM eclipse-temurin:21-jdk-jammy AS extractor
WORKDIR /JavaPrograms

COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh

# Copy imageio-ext 1.3.2 jars (includes OpenJPEG, Kakadu, and other plugins)
COPY --from=downloader /output/*.jar /JavaPrograms/CTP/libraries/imageio/


FROM eclipse-temurin:21-jre-jammy
WORKDIR /JavaPrograms

# Install OpenJPEG native library for imageio-ext JPEG2000 support
RUN apt-get update && apt-get install -y --no-install-recommends libopenjp2-7 && rm -rf /var/lib/apt/lists/*

COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP

EXPOSE 80

ENTRYPOINT ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.base/java.util=ALL-UNNAMED", "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio.stream=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED", "-Djava.awt.headless=true", "-Djava.library.path=/usr/lib/x86_64-linux-gnu", "-jar", "Runner.jar"]
