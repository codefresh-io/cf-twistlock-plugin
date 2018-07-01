FROM endeveit/docker-jq
WORKDIR /home
COPY . .
RUN ls -alh /home
#ENTRYPOINT [ "sh /home/entrypoint.sh" ]
#CMD sh -c "ls -alh && pwd"
ENTRYPOINT /home/entrypoint.sh