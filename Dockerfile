FROM google/dart:latest

WORKDIR /app

COPY deployment/pubspec.* ./
RUN dart pub get

COPY deployment/ ./

EXPOSE 8080

CMD ["dart", "run", "bin/main.dart"]
