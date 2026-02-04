FROM google/dart:latest

WORKDIR /app

COPY deployment/pubspec.yaml deployment/pubspec.lock ./

RUN dart pub get

COPY deployment/bin ./bin

EXPOSE 8080

CMD ["dart", "run", "bin/main.dart"]
