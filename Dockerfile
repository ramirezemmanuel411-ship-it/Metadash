FROM google/dart:latest

WORKDIR /app

COPY deployment/ ./

RUN dart pub get

EXPOSE 8080

CMD ["dart", "run", "bin/main.dart"]
