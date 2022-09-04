ARG sysroot=/mnt/sysroot
ARG SYSLOGD_CMDLINE
FROM fedora:36 as builder
ARG sysroot
ARG DISTVERSION=36
ARG DNFOPTION="--setopt=install_weak_deps=False --nodocs"

#update builder
RUN dnf makecache && dnf -y update
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
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install busybox libcap libestr libfastjson libgcrypt libgpg-error libuuid libzstd lz4-libs p11-kit systemd-libs xz-libs zlib
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install --downloadonly --downloaddir=./ initscripts rsyslog

COPY ./script.sh "${sysroot}/script.sh"

RUN chmod +u+x "${sysroot}/script.sh" && chroot ${sysroot} /script.sh && rm "${sysroot}/script.sh"

# RUN ARCH="$(uname -m)" \
    # && TLSRPM="$(ls gnutls*${ARCH}.rpm)" \
    # && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${TLSRPM}

#install rsyslog
RUN ARCH="$(uname -m)" \
    && RSYSPRPM="$(ls rsyslog*${ARCH}.rpm)" \
    && RSYSVERSION=$(sed -e "s/rsyslog-\(.*\)\.${ARCH}.rpm/\1/" <<< $RSYSPRPM) \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${RSYSPRPM} \
    && printf ${RSYSVERSION} > ${sysroot}/rsyslog.version

RUN cat << EOF | tee ${sysroot}/etc/sysconfig/network \
    NETWORKING=yes \
    HOSTNAME=localhost.localdomain\
    EOF
 
 COPY "./rsyslog.conf" "${sysroot}/etc/rsyslog.conf"
 COPY "./rsyslog.service" "${sysroot}/etc/rc.d/init.d/rsyslog.service"
 COPY "./entrypoint.sh"  "${sysroot}/bin/entrypoint.sh"
 
 RUN chroot ${sysroot} chmod u+x  /etc/rc.d/init.d/rsyslog.service /bin/entrypoint.sh
 
#clean up
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} remove shadow-utils 
    # && dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} remove util-linux-core --skip-broken \
    # && cp /usr/bin/logger ${sysroot}/usr/bin/logger
    
RUN ARCH="$(uname -m)" \
    && INITRPM="$(ls initscripts*${arch}.rpm)" \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${INITRPM}
    
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  autoremove \    
    && dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  clean all \
    && rm -rf ${sysroot}/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
#  docs and man pages       
    && rm -rf ${sysroot}/usr/share/{man,doc,info,gnome/help} \
#  purge log files
    && rm -f ${sysroot}/var/log/*|| exit 0 \
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
ARG sysroot
ARG SYSLOGD_CMDLINE
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
ENV SYSLOGD_CMDLINE=${SYSLOGD_CMDLINE}
ENTRYPOINT ["./tini", "--", "/bin/entrypoint.sh"]
CMD ["start"]
