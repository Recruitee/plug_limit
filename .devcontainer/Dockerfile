FROM elixir:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update \
  && apt-get -qq --no-install-recommends install \
  fish \
  redis \
  supervisor

COPY supervisord.conf /etc/supervisor/supervisord.conf
