# 
# Dockerfile based on work of https://hub.docker.com/_/ubuntu-upstart/
# and inspired by https://github.com/okvic77/docker-airtime
#
FROM ubuntu:trusty

# ENV LANG en_US.UTF-8
# ENV LANGUAGE en_US:en
# ENV LC_ALL en_US.UTF-8
ENV HOSTNAME localhost
ENV DEBIAN_FRONTEND=noninteractive
# let Upstart know it's in a container
ENV container docker

MAINTAINER Hans-Joachim

#
# Install some rudimental stuff
RUN locale-gen --purge en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8  LANGUAGE=en_US:en  LC_ALL=en_US.UTF-8 \
    && apt-get update && apt-get dist-upgrade -y \
    && apt-get install -y  python-psycopg2 nano \
        git rabbitmq-server apache2 curl postgresql postgresql-contrib

# Install dependecies beforehand to speed up development
COPY ./libretime/installer/lib/requirements-ubuntu-trusty.apt /tmp
RUN apt-get update && apt-get -y -m --force-yes install $(grep -vE '^\s*#' /tmp/requirements-ubuntu-trusty.apt | tr '\n' ' ')

ADD libretime/ /libretime_src/libretime
#
# Install libretime
#
COPY help/prep_os.sh /prep_os.sh
RUN /prep_os.sh

ADD init-fake.conf /etc/init/fake-container-events.conf

# undo some leet hax of the base image
RUN rm /usr/sbin/policy-rc.d; \
    rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl

# remove some pointless services
RUN /usr/sbin/update-rc.d -f ondemand remove; \
	for f in \
		/etc/init/u*.conf \
		/etc/init/mounted-dev.conf \
		/etc/init/mounted-proc.conf \
		/etc/init/mounted-run.conf \
		/etc/init/mounted-tmp.conf \
		/etc/init/mounted-var.conf \
		/etc/init/hostname.conf \
		/etc/init/networking.conf \
		/etc/init/tty*.conf \
		/etc/init/plymouth*.conf \
		/etc/init/hwclock*.conf \
		/etc/init/module*.conf\
	; do \
		dpkg-divert --local --rename --add "$f"; \
	done; \
	echo '# /lib/init/fstab: cleared out for bare-bones Docker' > /lib/init/fstab

# install legacy silan due to bug #197
# TODO clean this once it is merged to master
RUN echo 'deb http://apt.sourcefabric.org/ trusty main' >> /etc/apt/sources.list \
	&& apt-get update && apt-get install -y --force-yes sourcefabric-keyring \
	&& apt-get update && apt-get install -y --force-yes --reinstall silan=0.3.2~trusty~sfo-1

# copy the script for the 1st run
COPY 1st_start.conf /etc/init

# pass HTTPS var to PHP server
RUN echo 'SetEnv HTTPS 1' > /etc/apache2/conf-enabled/expose-env.conf

# watching folder kickstarter script into container
COPY libretime/python_apps/libretime_watch/libretime_watch/start_watching.py /opt

VOLUME ["/etc/airtime", "/var/lib/postgresql", "/srv/airtime/stor", "/srv/airtime/watch"]

EXPOSE 80 8000

CMD ["/sbin/init"]
