FROM fedora:36 as builder
ENV DISTTAG=f36container FGC=f36 FBR=f36 container=podman
ARG DISTVERSION=36
ARG sysroot=/mnt/sysroot
ARG DNFOPTION="--setopt=install_weak_deps=False --nodocs"

#update builder
RUN dnf makecache  && dnf -y update
#install system
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install glibc setup shadow-utils

RUN yes | rm -f ${sysroot}/dev/null \
    &&mknod -m 600 ${sysroot}/dev/initctl p \
    && mknod -m 666 ${sysroot}/dev/full c 1 7 \
    && mknod -m 666 ${sysroot}/dev/null c 1 3 \
    && mknod -m 666 ${sysroot}/dev/ptmx c 5 2 \
    && mknod -m 666 ${sysroot}/dev/random c 1 8 \
    && mknod -m 666 ${sysroot}/dev/tty c 5 0 \
    && mknod -m 666 ${sysroot}/dev/tty0 c 4 0 \
    && mknod -m 666 ${sysroot}/dev/urandom c 1 9


#dhcpd prerequisites
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install coreutils libcap libestr libfastjson libgcrypt libgpg-error libzstd libuuid lz4-libs p11-kit procps-ng util-linux xz-libs 
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install --downloadonly --downloaddir=./ gnutls initscripts rsyslog

RUN ARCH="$(uname -m)" \
    && TLSRPM="$(ls gnutls*${ARCH}.rpm)" \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${TLSRPM}

#install rsyslog
RUN ARCH="$(uname -m)" \
    && RSYSPRPM="$(ls rsyslog*${ARCH}.rpm)" \
    && RSYSVERSION=$(sed -e "s/rsyslog-\(.*\)\.${ARCH}.rpm/\1/" <<< $RSYSPRPM) \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${RSYSPRPM} \
    && printf ${RSYSVERSION} > ${sysroot}/rsyslog.version
 
 COPY "./rsyslog.conf" "${sysroot}/etc/rsyslog.conf"
 COPY "./rsyslog.service" "${sysroot}/etc/rc.d/init.d/rsyslog.service"
 COPY "./entrypoint.sh"  "${sysroot}/bin/entrypoint.sh"
 
 RUN chroot ${sysroot} chmod u+x  /etc/rc.d/init.d/rsyslog.service /bin/entrypoint.sh
 
 #clean up
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} remove shadow-utils \
    && dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} remove util-linux-core --skip-broken
    
RUN ARCH="$(uname -m)" \
    && INITRPM="$(ls initscripts*${arch}.rpm)" \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${INITRPM}
    
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  autoremove \    
    && dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  clean all \
    && rm -rf ${sysroot}/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
#  docs and man pages       
    && rm -rf ${sysroot}/usr/share/{man,doc,info,gnome/help} \
#  purge log files
    && rm -f ${sysroot}/var/log/* \
#  cracklib
    && rm -rf ${sysroot}/usr/share/cracklib \
#  i18n
    && rm -rf ${sysroot}/usr/share/i18n \
#  dnf cache
    && rm -rf ${sysroot}/var/cache/dnf/ \
    && mkdir -p --mode=0755 ${sysroot}/var/cache/dnf/ \
    && rm -f ${sysroot}//var/lib/dnf/history.* \
#  sln
    && rm -rf ${sysroot}/sbin/sln \
#  ldconfig
    && rm -rf ${sysroot}/etc/ld.so.cache ${sysroot}/var/cache/ldconfig \
    && mkdir -p --mode=0755 ${sysroot}/var/cache/ldconfig

FROM scratch 
ARG sysroot=/mnt/sysroot
COPY --from=builder ${sysroot} /
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENV DISTTAG=f36container FGC=f36 FBR=f36 container=podman
ENV DISTRIB_ID fedora
ENV DISTRIB_RELEASE 36
ENV PLATFORM_ID "platform:f36"
ENV DISTRIB_DESCRIPTION "Fedora 36 Container"
ENV TZ UTC
ENV LANG C.UTF-8
ENV TERM xterm
ENTRYPOINT ["./tini", "--", "/bin/entrypoint.sh"]
CMD ["start", "stop","restart"]
