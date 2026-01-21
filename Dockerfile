FROM ruby:3.4-alpine

RUN apk add --no-cache build-base

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:4567"]
