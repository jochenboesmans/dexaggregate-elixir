FROM bitwalker/alpine-elixir-phoenix:latest AS phx-builder

ENV MIX_ENV=prod

RUN mix local.hex --force && \
	mix local.rebar --force
ADD mix.exs mix.lock ./ 
RUN mix do deps.get, deps.compile

ADD . .

FROM bitwalker/alpine-elixir:latest

EXPOSE 4001
ENV PORT=4001 MIX_ENV=prod

COPY --from=phx-builder /opt/app/_build /opt/app/_build
COPY --from=phx-builder /opt/app/config /opt/app/config
COPY --from=phx-builder /opt/app/lib /opt/app/lib
COPY --from=phx-builder /opt/app/deps /opt/app/deps
COPY --from=phx-builder /opt/app/.mix /opt/app/.mix
COPY --from=phx-builder /opt/app/mix.* /opt/app/

USER default

CMD ["MIX_ENV=prod", "mix", "phx.server"]
