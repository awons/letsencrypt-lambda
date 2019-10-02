FROM amazonlinux:2018.03.0.20190826 as development

RUN sed -i 's;^releasever.*;releasever=2018.03;;' /etc/yum.conf && \
    yum clean all && \
    yum install -y autoconf \
                bison \
                bzip2-devel \
                gcc \
                gcc-c++ \
                git \
                gzip \
                libcurl-devel \
                libxml2-devel \
                make \
                openssl-devel \
                tar \
                unzip \
                wget \
                zip

RUN wget https://www.python.org/ftp/python/3.6.8/Python-3.6.8.tgz\
    && tar -xzvf Python-3.6.8.tgz\
    && cd Python-3.6.8\
    && ./configure\
    && make install

RUN /usr/local/bin/pip3 install --upgrade pip\
    && /usr/local/bin/pip3 install virtualenv

RUN cd && /usr/local/bin/virtualenv venv\
    && source venv/bin/activate\
    && pip install --target /opt/python/lib/python3.6/site-packages boto3 certbot certbot-dns-route53 sentry-sdk

FROM lambci/lambda:python3.6 as runtime

COPY --from=development /opt /opt


FROM runtime as function

COPY src /var/task
