#!/usr/bin/env bash

REPOSITORY=${REPOSITORY:-"ttl.sh"}
PUSH=${PUSH:-"false"}

for dir in */; do
  if [ ! -d "usr/" ]; then
      echo "$dir doesnt look like a sysextension, skipping"
  fi
  name=$(echo "${dir%/}" | cut -d'-' -f1)
  version=$(echo "${dir%/}" | cut -d'-' -f2)
  if [ -z "$version" ]; then
      version="latest"
  fi
  # Replace + with _
  docker_version=$(echo "$version" | tr '+' '_')
  # Ensure it's lowercase
  docker_version=$(echo "$docker_version" | tr '[:upper:]' '[:lower:]')
  pushd "$dir" || exit 1
  cat <<EOF > .dockerignore
Dockerfile
EOF
  cat <<EOF > Dockerfile
FROM scratch
COPY . /
EOF
  docker build -t "$REPOSITORY"/"$name":"$docker_version" .
  rm Dockerfile
  rm .dockerignore
  if [ "$PUSH" = "true" ]; then
      docker push "$REPOSITORY"/"$name":"$docker_version"
  fi
  popd || exit 1
done