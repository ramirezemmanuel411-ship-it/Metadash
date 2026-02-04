FROM google/dart:latest

WORKDIR /app

# Copy only the deployment folder contents
COPY deployment/pubspec.yaml .
COPY deployment/pubspec.lock .
COPY deployment/bin ./bin

RUN dart pub get

EXPOSE 8080

CMD ["dart", "run", "bin/main.dart"]
