FROM ruby:2.3-slim

# install common tools
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl openssl git libpq-dev build-essential vim dnsutils openssh-client zip wget && \
  rm -rf /tmp/* /var/lib/apt/lists/*

# set envvar
ENV EDITOR=vim PATH=$PATH:/opt/terraform

# caching dependencies
COPY ["Gemfile", "Gemfile.lock", "/tmp/build/"]
COPY ["vendor", "/tmp/build/vendor"]

RUN cd /tmp/build && \
  bundle install --no-cache && \
  rm -rf /tmp/build

# copy code
COPY . /root/app/
WORKDIR /root/app
RUN ["bundle", "install", "--no-cache"]

CMD ["/bin/bash"]
