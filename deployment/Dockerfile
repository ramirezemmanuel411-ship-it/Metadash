FROM google/dart:latest

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
COPY bin ./bin

RUN dart pub get

EXPOSE 8080

CMD ["dart", "run", "bin/main.dart"]
