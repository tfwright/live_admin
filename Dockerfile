FROM hexpm/elixir:1.16.0-erlang-26.2.1-debian-bullseye-20231009-slim

RUN apt-get update -y && apt-get install -y build-essential git nodejs npm curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y nodejs

WORKDIR /opt/app

ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

ADD assets assets/
RUN npm --prefix assets install
RUN npm --prefix assets run build
