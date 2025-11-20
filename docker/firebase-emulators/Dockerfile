FROM node:20-bullseye-slim

RUN npm i -g firebase-tools@13.9.0 && \
    apt-get update && apt-get install -y openjdk-17-jre-headless curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Cache emulators on build to speed up startup
RUN firebase setup:emulators:firestore && \
    firebase setup:emulators:ui && \
    firebase setup:emulators:auth || true

EXPOSE 4000 8080 9099

CMD ["bash", "-lc", "firebase --version && firebase emulators:start"]
