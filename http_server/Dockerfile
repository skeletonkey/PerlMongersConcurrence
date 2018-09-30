FROM perl:5.28
MAINTAINER Erik Tank <erik.tank@ticketmaster.com>

WORKDIR /code

RUN echo 'alias ll="ls -al"' >> ~/.bashrc;

RUN cpanm install Plack
RUN cpanm install JSON::XS

CMD perl /code/randomly_create_touch_file.pl; plackup /code/healthcheck.psgi
