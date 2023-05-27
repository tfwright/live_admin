FROM bitwalker/alpine-elixir-phoenix:1.13

ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

ADD assets assets/
RUN npm --prefix assets install
RUN npm --prefix assets run build
