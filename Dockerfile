FROM hexpm/elixir:1.19.5-erlang-26.2.5-ubuntu-jammy-20251013

RUN apt-get update -y && apt-get install -y build-essential git curl inotify-tools \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y nodejs

WORKDIR /opt/app

ADD mix.exs mix.lock ./
RUN mix do deps.get, compile

ADD assets assets/
RUN npm --prefix assets ci --force
