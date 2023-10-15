FROM hexpm/elixir:1.15.7-erlang-25.3.2.7-debian-buster-20230612-slim

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
