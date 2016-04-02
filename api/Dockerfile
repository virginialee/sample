FROM myobplatform/scala-play:2.11-2.5.0

# caching dependencies
COPY ["build.sbt", "/tmp/build/"]
COPY ["project/plugins.sbt", "/project/build.properties", "/tmp/build/project/"]
RUN cd /tmp/build && \
  activator compile && \
  activator test:compile && \
  rm -rf /tmp/build

# need to remove logs, public and target directory?

# copy code
COPY . /root/app/
WORKDIR /root/app
#RUN activator compile && activator test:compile

EXPOSE 9000
CMD ["activator"]