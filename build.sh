#!/usr/bin/env bash


for dir in */; do
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
  cat <<EOF > Dockerfile
FROM scratch
COPY * /
EOF
  docker build -t "$name":"$docker_version" .
  rm Dockerfile
  popd || exit 1
done