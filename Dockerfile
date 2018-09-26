FROM centos:centos7

ENV container zeppelin

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Add script to download JDK from Oracle
ADD get-java.sh /usr/sbin/get-java.sh
RUN chmod -v 777 /usr/sbin/get-java.sh \
	&& sed -i -e 's/\r$//' /usr/sbin/get-java.sh
	
#Install Oracle JVM
RUN yum -y install wget \ 
	#&& wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$java_version-b$java_bnumber/$java_hash/jdk-$java_version-linux-x64.tar.gz" \
	#&& wget --timeout=1 --tries=5 --retry-connrefused --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/10.0.1+10/fb4372174a714e6b8c52526dc134031e/jdk-10.0.1_linux-x64_bin.tar.gz \

RUN java_version=8u181; \
	java_bnumber=13; \
	java_semver=1.8.0_181; \
	java_hash=96a7b8442fe848ef90c96a2fad6ed6d1; \
	/usr/sbin/get-java.sh 8 tar.gz \
	&& tar -zxvf jdk-8u181-linux-x64.tar.gz -C /opt \
	&& rm jdk-8u181-linux-x64.tar.gz \
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

# Install ntp
RUN yum install -y ntp && yum clean all
	
# Install FreeIPA client and download Hortonworks distribution
RUN yum install -y ipa-client dbus-python perl 'perl(Data::Dumper)' 'perl(Time::HiRes)' && yum clean all

ARG zeppelin_user=zeppelinUser
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

## Patch per zeppelin
#RUN export http_proxy=http://proxy-srv.csi.it:3128; \
#export https_proxy=http://proxy-srv.csi.it:3128; \

ADD /patch-zeppelin/zeppelin.sh /tmp/zeppelin.sh
ADD /patch-zeppelin/interpreter.sh /tmp/interpreter.sh
ADD /patch-zeppelin/zeppelin-web-0.7.0.2.6.0.3-8.war /tmp/zeppelin-web-0.7.0.2.6.0.3-8.war
#RUN wget --no-check-certificate https://raw.githubusercontent.com/PeterCahn/CentOS-base/master/patch-zeppelin/zeppelin.sh -P /tmp  && \ 
#	wget --no-check-certificate https://raw.githubusercontent.com/PeterCahn/CentOS-base/master/patch-zeppelin/interpreter.sh -P /tmp && \ 
#	wget --no-check-certificate https://github.com/PeterCahn/CentOS-base/raw/master/patch-zeppelin/zeppelin-web-0.7.0.2.6.0.3-8.war -P /tmp && \
RUN	chmod 777 /tmp/*.sh && \
	/bin/cp -f /tmp/zeppelin.sh /usr/hdp/2.6.0.3-8/zeppelin/bin/ && \ 
	/bin/cp -f /tmp/interpreter.sh /usr/hdp/2.6.0.3-8/zeppelin/bin/ && \ 
	/bin/cp -f /tmp/zeppelin-web-0.7.0.2.6.0.3-8.war /usr/hdp/2.6.0.3-8/zeppelin/lib/ && \
	rm -f /tmp/*.sh && \
	rm -f /tmp/*.war
	
VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]