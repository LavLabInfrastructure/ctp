FROM curlimages/curl AS downloader
RUN curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar && \
    curl -fL -o /tmp/imageio-ext-jars.zip https://demo.geo-solutions.it/share/github/imageio-ext/releases/1.3.X/1.3.2/imageio-ext-1.3.2-jars.zip && \
    mkdir /tmp/imageio && cd /tmp/imageio && unzip -q ../imageio-ext-jars.zip

FROM eclipse-temurin:21-jdk-jammy AS extractor
WORKDIR /JavaPrograms

COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh && rm -rf /JavaPrograms/CTP/libraries/imageio/ && \
    mkdir /JavaPrograms/CTP/libraries/imageio/

COPY --from=downloader /tmp/imageio/*.jar /JavaPrograms/CTP/libraries/imageio/


FROM eclipse-temurin:21-jre-jammy
WORKDIR /JavaPrograms/CTP

RUN apt-get update && apt-get install -y --no-install-recommends \
    gdal-bin \
    libgdal30 \
    libturbojpeg0 \
    && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib:/lib:/usr/lib/jni
ENV JAVA_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib:/lib:/usr/lib/jni

COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP

WORKDIR /JavaPrograms/CTP

EXPOSE 80

ENTRYPOINT ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.base/java.util=ALL-UNNAMED", "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio.stream=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED", "-Djava.awt.headless=true", "-Djava.library.path=/usr/lib/x86_64-linux-gnu:/usr/lib:/lib", "-Dcom.sun.media.imageio.stream.buffersize=65536", "-jar", "Runner.jar"]
