# Solar AI Blog Platform - E2B Development Environment with AI Content Generation
FROM node:21-slim

RUN apt-get update && apt-get install -y curl git python3 python3-pip python3-venv libpq5 build-essential && apt-get clean && rm -rf /var/lib/apt/lists/*

# The installer requires curl (and certificates) to download the release archive
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates

# Download the latest installer
ADD https://astral.sh/uv/install.sh /uv-installer.sh

# Run the installer then remove it
RUN sh /uv-installer.sh && rm /uv-installer.sh

# Install pnpm
RUN npm install -g pnpm

# Move uv to non-root path
RUN cp /root/.local/bin/uv /usr/local/bin/uv

# Ensure the installed binary is on the `PATH`
ENV PATH="/root/.local/bin/:$PATH"

# Install dependencies and customize sandbox
WORKDIR /home/user

# Set up Git configurations
RUN git config --global user.email "blog@leverageai.com" && git config --global user.name "leverageai-blog-platform"

# Add build argument for cache busting
ARG BUST=1

# Create app directory and copy template files
RUN mkdir -p /home/user/app
COPY app/ /home/user/app/

WORKDIR /home/user/app
RUN mkdir -p /home/user/app/logs
RUN pnpm install

# Create a directory for the FastAPI server
RUN mkdir -p /home/user/services
COPY services/ /home/user/services/

# Create a directory for the FastAPI logging server
RUN mkdir -p /home/user/logging-server
COPY logging-server/ /home/user/logging-server/

# Install AI and content generation dependencies
RUN apt-get update && apt-get install -y \
    pandoc \
    wkhtmltopdf \
    imagemagick \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Sync the project into a new environment, using the frozen lockfile
WORKDIR /home/user/services
RUN uv add openai nltk textstat yake newspaper3k
RUN uv add python-slugify feedgen python-wordpress-xmlrpc
RUN uv add tweepy linkedin-api facebook-sdk
RUN uv sync --frozen

# Download NLTK data for content analysis
RUN uv run python -c "import nltk; nltk.download('punkt'); nltk.download('stopwords'); nltk.download('vader_lexicon')"

# Expose ports for blog platform interface and API
EXPOSE 5173 8000

# Start script for AI blog platform environment
RUN echo '#!/bin/bash\
set -e\
\
# Start FastAPI backend with AI blog services\
cd /home/user/services\
uv run uvicorn main:app --host 0.0.0.0 --port 8000 &\
\
# Start frontend development server\
cd /home/user/app\
pnpm dev --host 0.0.0.0\
' > /home/user/start.sh && chmod +x /home/user/start.sh

CMD ["/home/user/start.sh"]