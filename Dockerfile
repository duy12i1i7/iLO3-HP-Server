FROM ubuntu:16.04

# Configure mirror for faster downloads and bypass rate-limiting
RUN echo "deb http://mirror.math.princeton.edu/pub/ubuntu/ xenial main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirror.math.princeton.edu/pub/ubuntu/ xenial-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirror.math.princeton.edu/pub/ubuntu/ xenial-security main restricted universe multiverse" >> /etc/apt/sources.list

# Install Nginx 1.10.3 which ships with OpenSSL 1.0.2g
RUN apt-get update && apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/*

# Copy configuration files (mounted at runtime)
# RUN rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Expose ports
EXPOSE 80 443

# Run Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
