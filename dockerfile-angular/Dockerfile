# Use Nginx version 1.23.2-alpine as the base image
FROM nginx:1.23.2-alpine

# Copy the pre-configured nginx.conf file to the correct location in the container
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the 'dist' folder, which is the result of building Angular from the host (outside Docker),
# to the directory Nginx uses for hosting files (default: /usr/share/nginx/html).
# This implies that the Angular application was built before creating the Docker image.
COPY dist /usr/share/nginx/html

# Expose port 80 to allow Nginx to receive requests
EXPOSE 80

# Install ca-certificates for secure HTTPS connections
RUN apk add ca-certificates && update-ca-certificates
# Change TimeZone to Asia/Bangkok
RUN apk add --update tzdata
ENV TZ=Asia/Bangkok
# Clean APK cache to reduce image size
RUN rm -rf /var/cache/apk/*

# Default command to run when the container starts: run Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
