#FROM krallin/centos-tini:centos7
FROM centos:7

ENV container docker
ENV http_proxy http://proxy.csi.it:3128
ENV https_proxy  http://proxy.csi.it:3128

# Add script to download JDK from Oracle
ADD get-java.sh /usr/sbin/get-java.sh
RUN chmod -v +rwx /usr/sbin/get-java.sh \
	&& sed -i -e 's/\r$//' /usr/sbin/get-java.sh

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

#enable cache
#RUN sed -i 's/keepcache=0/keepcache=1/g' /etc/yum.conf

#Install Oracle JVM
RUN java_version=8u181; \
    java_bnumber=11; \
    java_semver=1.8.0_181; \
    java_hash=429c3184b10d7af2bb5db3faf20b467566eb5bd95778f8339352c180c8ba48a1; \
    yum -y install wget && yum clean all \
	&& /usr/sbin/get-java.sh 8 tar.gz \
    && tar -zxvf jdk-$java_version-linux-x64.tar.gz -C /opt \
    && rm jdk-$java_version-linux-x64.tar.gz \
    && ln -sf /opt/jdk$java_semver/ /opt/jre-home \
    && alternatives --install /usr/bin/java java /opt/jdk$java_semver/jre/bin/java 20000 \
    && alternatives --install /usr/bin/jar jar /opt/jdk$java_semver/bin/jar 20000 \
    && alternatives --install /usr/bin/javac javac /opt/jdk$java_semver/bin/javac 20000 \
    && alternatives --install /usr/bin/javaws javaws /opt/jdk$java_semver/jre/bin/javaws 20000 \
    && alternatives --set java /opt/jdk$java_semver/jre/bin/java \
    && alternatives --set javaws /opt/jdk$java_semver/jre/bin/javaws \
    && alternatives --set javac /opt/jdk$java_semver/bin/javac \
    && alternatives --set jar /opt/jdk$java_semver/bin/jar \
    && java -version

RUN yum -y install unzip  && yum clean all \
    && wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip \
    && echo "f3020a3922efd6626c2fff45695d527f34a8020e938a49292561f18ad1320b59  jce_policy-8.zip" | sha256sum -c - \
    && unzip -oj jce_policy-8.zip UnlimitedJCEPolicyJDK8/local_policy.jar -d /opt/jre-home/jre/lib/security/ \
    && unzip -oj jce_policy-8.zip UnlimitedJCEPolicyJDK8/US_export_policy.jar -d /opt/jre-home/jre/lib/security/ \
    && rm jce_policy-8.zip \
    && chmod -R 640 /opt/jre-home/jre/lib/security/ \
	&& chown -R root:root /opt/jre-home/jre/lib/security/
	
# Install FreeIPA client and download Hortonworks distribution
RUN yum install -y ipa-client dbus-python perl 'perl(Data::Dumper)' 'perl(Time::HiRes)' && yum clean all 

ARG zeppelin_user=zeppelin_dock1
ENV env_zeppelin_user=$zeppelin_user

# Install Zeppelin
RUN useradd -ms /bin/bash $env_zeppelin_user \
	&& wget -nv -O /etc/yum.repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.0.3/hdp.repo \
    && yum install -y ambari-agent-2.5.0.3-7.x86_64 zeppelin_2_6_0_3_8-0.7.0.2.6.0.3-8.noarch && yum clean all \
    && chown -R $env_zeppelin_user:$env_zeppelin_user /etc/zeppelin/ \
    && chown -R $env_zeppelin_user:$env_zeppelin_user /var/lib/zeppelin/ \
    && chown -R $env_zeppelin_user:$env_zeppelin_user /var/run/zeppelin/ \
    && chown -R $env_zeppelin_user:$env_zeppelin_user /var/log/zeppelin/ \
#    && chown -R $env_zeppelin_user:$env_zeppelin_user /usr/hdp/2.6.0.3-8/zeppelin/webapps \
#    && chown -R $env_zeppelin_user:$env_zeppelin_user /usr/hdp/2.6.0.3-8/zeppelin/conf/interpreter.json \
    && chown -R $env_zeppelin_user:$env_zeppelin_user /usr/hdp/2.6.0.3-8/zeppelin/local-repo \
    && ls -lat /usr/hdp/2.6.0.3-8/zeppelin/interpreter/sh
	
VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]