FROM endeveit/docker-jq
WORKDIR /home
COPY . .
ENTRYPOINT /home/entrypoint.sh