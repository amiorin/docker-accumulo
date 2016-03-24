FROM centos:7
MAINTAINER Steffen Roegner "steffen.roegner@gmail.com"
USER root

ENV JAVA_HOME=/usr
ENV HADOOP_HOME=/usr/hdp/current/hadoop-client
ENV HADOOP_HDFS_HOME=/usr/hdp/current/hadoop-hdfs-client
ENV HADOOP_MAPRED_HOME=/usr/hdp/current/hadoop-mapreduce-client
ENV HADOOP_YARN_HOME=/usr/hdp/current/hadoop-yarn-client
ENV HADOOP_LIBEXEC_DIR=/usr/hdp/current/hadoop-client/libexec
ENV CONSUL_VERSION=0.5.2
ENV CONSUL_TEMPLATE_VERSION=0.9.0
ENV ACCUMULO_VERSION=1.7.1

ENV REFRESHED_AT 2015-06-08

RUN rpm -ivh http://epel.mirror.constant.com/7/x86_64/e/epel-release-7-5.noarch.rpm; \
    yum -y -q upgrade; \
    yum -y install tar snappy lzo which bind-utils java-1.7.0-openjdk-devel unzip supervisor gcc-c++ openssh-clients openssh-server pssh; \
    curl -L http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.2.4.2/hdp.repo -o /etc/yum.repos.d/hdp.repo; \
    curl -L http://apache.osuosl.org/accumulo/${ACCUMULO_VERSION}/accumulo-${ACCUMULO_VERSION}-bin.tar.gz | tar xz --no-same-owner -C /usr/lib; \
    yum -y install hadoop hadoop-hdfs hadoop-libhdfs hadoop-yarn hadoop-mapreduce hadoop-client zookeeper; \
    yum clean all
    
RUN mkdir -p /data1/hdfs /data1/mapred /data1/yarn /var/log/hadoop /var/log/hadoop-yarn /var/log/supervisor /var/log/consul /var/lib/consul/data /var/lib/consul/ui /etc/consul /etc/consul-leader /var/lib/zookeeper; \
    chown hdfs.hadoop /data1/hdfs && \
    chown mapred.hadoop /data1/mapred && \
    chown yarn.hadoop /data1/yarn; \
    chown zookeeper.hadoop /var/lib/zookeeper; \
    chmod 775 /var/log/hadoop; chgrp hadoop /var/log/hadoop; \
    cd /usr/sbin; \
    curl -L https://github.com/hashicorp/consul-template/releases/download/v${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.tar.gz | tar xz --no-same-owner --strip-components=1 && \
    curl -L https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o /tmp/c.zip && \
    curl -L https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_web_ui.zip -o /tmp/ui.zip && \
    unzip /tmp/c.zip -d /usr/sbin && \
    unzip /tmp/ui.zip -d /var/lib/consul/ui

COPY config/accumulo /var/lib/accumulo/conf/

RUN ln -s /usr/lib/accumulo-${ACCUMULO_VERSION} /usr/lib/accumulo; \
    useradd -u 6040 -G hadoop -d /var/lib/accumulo accumulo; \
    mkdir -p /etc/accumulo /var/lib/accumulo/conf /var/log/accumulo; \
    chown -R accumulo.accumulo /var/lib/accumulo /var/log/accumulo; \
    mv /usr/lib/accumulo/conf /usr/lib/accumulo/conf.dist; \
    rm -rf /usr/lib/accumulo/logs; \
    ln -s /var/lib/accumulo/conf /usr/lib/accumulo/conf; \
    ln -s /var/lib/accumulo/conf /etc/accumulo/conf; \
    ln -s /var/log/accumulo /usr/lib/accumulo/logs; \
    JAVA_HOME=/usr/lib/jvm/java /usr/lib/accumulo/bin/build_native_library.sh

COPY config/ssh /etc/ssh/
RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa

COPY config/supervisord.conf /etc/
COPY config/hadoop /etc/hadoop/conf
COPY config/zookeeper /etc/zookeeper/conf/
COPY config/supervisor /etc/supervisor/conf.d/
COPY config/consul /etc/consul/
COPY config/consul/consul.json /etc/consul-leader/
COPY scripts /usr/local/sbin/

USER accumulo
RUN ssh-keygen -t rsa -b 2048 -f /var/lib/accumulo/.ssh/id_rsa -N "" && cp /var/lib/accumulo/.ssh/id_rsa.pub /var/lib/accumulo/.ssh/authorized_keys && chmod 600 /var/lib/accumulo/.ssh/authorized_keys

USER hdfs
RUN HADOOP_ROOT_LOGGER="WARN,console" /usr/bin/hdfs namenode -format
USER root

VOLUME /etc/hadoop/conf
