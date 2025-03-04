# ----------- BUILD STAGE ----------- #
FROM node:23.3.0-slim AS builder

# Installer pnpm et les dépendances système nécessaires
RUN npm install -g pnpm@9.15.4 && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    git \
    python3 \
    python3-pip \
    curl \
    node-gyp \
    ffmpeg \
    libtool-bin \
    autoconf \
    automake \
    libopus-dev \
    make \
    g++ \
    build-essential \
    libcairo2-dev \
    libjpeg-dev \
    libpango1.0-dev \
    libgif-dev \
    openssl \
    libssl-dev \
    libsecret-1-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Définir Python 3 comme version par défaut
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers nécessaires
COPY . .

# Mettre à jour les submodules avant d’installer les dépendances
RUN git submodule update --init --recursive

# Vérifier le contenu copié
RUN ls -la /app

# Vérifier que pnpm voit bien tous les packages du workspace
RUN pnpm list --depth=-1

# Installer les dépendances sans bloquer le fichier pnpm-lock.yaml
RUN pnpm install --no-frozen-lockfile

# Installer explicitement les modules supplémentaires nécessaires
RUN pnpm add @elizaos-plugins/client-twitter@workspace:* --filter ./agent
RUN pnpm add @elizaos-plugins/plugin-multiversx@github:elpulpo0/plugin-multiversx#AI_MegaWave_Hackathon --filter ./agent
RUN pnpm add @elizaos-plugins/client-telegram@workspace:* --filter ./agent
RUN pnpm add @elizaos/core@workspace:* --filter ./packages/client-twitter
RUN pnpm add @elizaos/core@workspace:* --filter ./packages/plugin-multiversx
RUN pnpm add @elizaos/core@workspace:* --filter ./packages/client-telegram

# Build du projet
RUN pnpm run build

# ----------- RUNTIME STAGE ----------- #
FROM node:23.3.0-slim

# Installer uniquement les dépendances runtime nécessaires
RUN npm install -g pnpm@9.15.4 && \
    apt-get update && \
    apt-get install -y git python3 ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Définir le répertoire de travail
WORKDIR /app

# Copier uniquement les fichiers nécessaires à l’exécution
COPY --from=builder /app/package.json ./ 
COPY --from=builder /app/pnpm-workspace.yaml ./ 
COPY --from=builder /app/.npmrc ./ 
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/agent ./agent
COPY --from=builder /app/client ./client
COPY --from=builder /app/packages ./packages 
COPY --from=builder /app/scripts ./scripts 
COPY --from=builder /app/characters ./characters

# Créer un utilisateur non-root et changer le propriétaire des fichiers
RUN useradd -ms /bin/bash appuser && chown -R appuser /app
USER appuser

# Exposer les ports nécessaires
EXPOSE 3000 5173

# Utiliser un ENTRYPOINT plus propre pour éviter les problèmes de PID
ENTRYPOINT ["pnpm", "start"]
