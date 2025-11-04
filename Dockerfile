FROM curlimages/curl AS downloader
RUN curl -fL -o /tmp/installer.jar https://github.com/johnperry/CTP/raw/x206/products/CTP-installer.jar

FROM eclipse-temurin:21-jdk-jammy AS extractor
WORKDIR /JavaPrograms

COPY --from=downloader /tmp/installer.jar /tmp/installer.jar
RUN cd /tmp && \
    jar -xf installer.jar && \
    mv CTP /JavaPrograms/CTP && \
    mv config/config.xml /JavaPrograms/CTP/config.xml && \
    chmod +x /JavaPrograms/CTP/linux/*.sh

FROM maven:3.9-eclipse-temurin-11 AS builder
WORKDIR /build

# Copy CTP's JAI ImageIO jars to use as dependencies
COPY --from=extractor /JavaPrograms/CTP/libraries/imageio/jai_imageio-1.2-pre-dr-b04.jar /build/deps/
COPY --from=extractor /JavaPrograms/CTP/libraries/imageio/clibwrapper_jiio-1.2-pre-dr-b04.jar /build/deps/

# Install the CTP JAI ImageIO jars to local Maven repo
RUN mvn install:install-file \
    -Dfile=/build/deps/jai_imageio-1.2-pre-dr-b04.jar \
    -DgroupId=net.java.dev.jai-imageio \
    -DartifactId=jai-imageio-core-standalone \
    -Dversion=1.2-pre-dr-b04-2014-09-13 \
    -Dpackaging=jar && \
    mvn install:install-file \
    -Dfile=/build/deps/clibwrapper_jiio-1.2-pre-dr-b04.jar \
    -DgroupId=com.sun.media \
    -DartifactId=clibwrapper_jiio \
    -Dversion=1.2-pre-dr-b04 \
    -Dpackaging=jar && \
    touch /build/dummy.zip && \
    mvn install:install-file \
    -Dfile=/build/dummy.zip \
    -DgroupId=com.sun.media \
    -DartifactId=clib_jiio \
    -Dversion=1.2-pre-dr-b04 \
    -Dpackaging=zip

# Clone and build the JPEG2000 plugin using CTP's JAI ImageIO as dependency
RUN apt-get update && apt-get install -y git && \
    git clone --depth 1 --branch jai-imageio-jpeg2000-1.2-pre-dr-b04-2014-09-13 https://github.com/jai-imageio/jai-imageio-jpeg2000.git && \
    cd jai-imageio-jpeg2000 && \
    sed -i 's/<source>1.5<\/source>/<source>1.8<\/source>/g' pom.xml && \
    sed -i 's/<target>1.5<\/target>/<target>1.8<\/target>/g' pom.xml && \
    sed -i 's/System.runFinalizersOnExit(true);/\/\/ System.runFinalizersOnExit(true); \/\/ Deprecated and removed in modern Java/g' src/main/java/jj2000/j2k/entropy/encoder/EBCOTRateAllocator.java && \
    sed -i 's/System.runFinalizersOnExit(true);/\/\/ System.runFinalizersOnExit(true); \/\/ Deprecated and removed in modern Java/g' src/main/java/jj2000/j2k/entropy/encoder/StdEntropyCoder.java && \
    sed -i 's/System.runFinalizersOnExit(true);/\/\/ System.runFinalizersOnExit(true); \/\/ Deprecated and removed in modern Java/g' src/main/java/jj2000/j2k/entropy/decoder/StdEntropyDecoder.java && \
    mvn clean package -DskipTests -Dmaven.javadoc.skip=true

FROM eclipse-temurin:21-jdk-jammy AS assembler
WORKDIR /JavaPrograms

# Copy extracted CTP
COPY --from=extractor /JavaPrograms/CTP /JavaPrograms/CTP

# Remove JPEG2000 classes from the bundled jai_imageio to avoid sealing violation
RUN cd /JavaPrograms/CTP/libraries/imageio && \
    mkdir temp && \
    cd temp && \
    jar xf ../jai_imageio-1.2-pre-dr-b04.jar && \
    rm -rf com/sun/media/imageioimpl/plugins/jpeg2000 && \
    jar cf ../jai_imageio-1.2-pre-dr-b04-patched.jar * && \
    cd .. && \
    rm -rf temp && \
    rm jai_imageio-1.2-pre-dr-b04.jar && \
    mv jai_imageio-1.2-pre-dr-b04-patched.jar jai_imageio-1.2-pre-dr-b04.jar

# Add the built JPEG2000 plugin
COPY --from=builder /build/jai-imageio-jpeg2000/target/jai-imageio-jpeg2000-1.2-pre-dr-b04-2014-09-13.jar /JavaPrograms/CTP/libraries/imageio/

FROM eclipse-temurin:21-jre-jammy
WORKDIR /JavaPrograms/CTP

COPY --from=assembler /JavaPrograms/CTP /JavaPrograms/CTP

EXPOSE 80

# Run with module opens and force pure-Java JPEG2000
ENTRYPOINT ["java", "--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.base/java.util=ALL-UNNAMED", "--add-opens=java.desktop/java.awt.image=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio.stream=ALL-UNNAMED", "--add-opens=java.desktop/javax.imageio=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED", "--add-exports=java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED", "-Djava.awt.headless=true", "-Dcom.sun.media.imageio.disableCodecLib=true", "-Dcom.sun.media.imageio.stream.buffersize=65536", "-jar", "Runner.jar"]
