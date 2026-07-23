# Fork image: build madness from the local (patched) source instead of
# installing the published gem, so the vault viewer picks up the fork's
# wikilink and callout changes.
FROM ruby:3.3-alpine

RUN apk add --no-cache build-base pandoc

WORKDIR /src
COPY . /src
RUN gem build madness.gemspec && gem install madness-*.gem && rm -rf /src

WORKDIR /docs
VOLUME /docs

EXPOSE 3000

ENTRYPOINT ["madness"]
