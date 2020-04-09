#!/bin/bash
#选择安装路径
workingPath=$1
cd $workingPath
#2、设置软件版本
httpdVersion=2.4.39
aprVersion=1.7.0
aprUtilVersion=1.6.1
phpVersion=7.3.5
#3、编写相关函数
install_php(){
	#3.1 安装依赖包
    yum clean all
    yum makecache

	yum install -y epel-release wget libxml2-devel gcc pcre-devel openssl-devel expat-devel autoconf libtool gcc-c++
	
	#3.2 下载官方镜像源代码和tar包
    wget https://www.php.net/distributions/php-${phpVersion}.tar.bz2
	wget http://mirrors.tuna.tsinghua.edu.cn/apache/apr/apr-${aprVersion}.tar.gz
	wget http://mirrors.tuna.tsinghua.edu.cn/apache/apr/apr-util-${aprUtilVersion}.tar.gz
 	wget https://mirrors.tuna.tsinghua.edu.cn/apache/httpd/httpd-${httpdVersion}.tar.gz
	tar xvf httpd-${httpdVersion}.tar.gz
	tar xvf apr-${aprVersion}.tar.gz -C httpd-${httpdVersion}/srclib/
	tar xvf apr-util-${aprUtilVersion}.tar.gz -C httpd-${httpdVersion}/srclib/
	cd httpd-2.4.39/srclib/
	mv apr-${aprVersion} apr
	mv apr-util-${aprUtilVersion} apr-util
	cd ..

	#3.3 配置和编译http

	./configure --prefix=/usr/local/httpd24 --enable-so --enable-ssl --enable-cgi --enable-rewrite --with-zlib --with-pcre --with-included-apr --enable-modules=most --enable-mpms-shared=all --with-mpm=prefork
	
	if [ $? -eq 0 ]; then	
		make && make install
		echo " make and make install"
	fi
        
    #3.4 为httpd daemon创建账户
	useradd -r apache -s /sbin/nologin 
     
	#3.5 修改the http配置
    sed -i 's@User = daemon@User = apache@' /usr/local/httpd24/conf/httpd.conf
	sed -i 's@Group = daemon@Group = apache@' /usr/local/httpd24/conf/httpd.conf

    cat >> /usr/local/httpd24/conf/httpd.conf <<-EOF
    LoadModule proxy_module modules/mod_proxy.so
    LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
    LoadModule proxy_fdpass_module modules/mod_proxy_fdpass.so

    ProxyRequests Off
    ProxyPassMatch ^/(.*\.php)$ unix:/var/run/php-fpm.sock|fcgi://localhost/usr/local/httpd24/htdocs/
    EOF

    echo '<?php phpinfo(); ?>' > /usr/local/httpd24/htdocs/index.php
        
    #3.6 设置httpd 环境变量运行apachectl
    cat > /etc/profile.d/httpd.sh <<-EOF
    PATH=/usr/local/httpd24/bin:\$PATH
    EOF

	#3.7 编译安装 php-fpm
	
	cd $workingPath
	tar xf php-7.3.5.tar.bz2
	cd php-7.3.5

	./configure --prefix=/usr/local/php --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-openssl --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib --with-config-file-path=/usr/loca/php/etc --with-config-file-scan-dir=/usr/local/php/etc/php.d --enable-mbstring --enable-xml --enable-sockets --enable-fpm --enable-maintainer-zts --disable-fileinfo
	make -j 4
	
	make install

	#3.8 配置 php-fpm
	cd /usr/local/php/etc/
	cp php-fpm.conf.default php-fpm.conf
	cd php-fpm.d/
    cp www.conf.default www.conf
	cd /root/php-7.3.5/sapi/fpm
	cp init.d.php-fpm /etc/init.d/php-fpm
	chmod 755 /etc/init.d/php-fpm

	sed -i 's@user = nobody@user = apache@' /usr/local/php/etc/php-fpm.d/www.conf
    sed -i 's@group = nobody@group = apache@' /usr/local/php/etc/php-fpm.d/www.conf
	sed -i 's@listen = 127.0.0.1:9000@listen = /var/run/php-fpm.sock@' /usr/local/php/etc/php-fpm.d/www.conf
	sed -i 's@;listen.mode = 0660@listen.mode = 0666@' /usr/local/php/etc/php-fpm.d/www.conf	
	
}

#4. 移除安装的软件
remove_php(){
	echo "remove php softwares"
	rm -rf /usr/local/httpd24
    rm -rf /usr/local/php
}

clean_php(){
	echo "clean php files"
	rm -rf $2
}

#5. 选择函数
case $1 in
install)
     install_php
     ;;
remove)
     remove_php
     ;;
clean)
     clean_php $1
     ;;
*)
     echo "Useage: phpinstall.sh  install | clean  workdir"
	 echo "Useage: phpinstall.sh  remove "
     ;;
esac
