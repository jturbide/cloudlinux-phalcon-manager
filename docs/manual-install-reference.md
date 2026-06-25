# Manual Install Reference

These commands are preserved as a reference for operators who want to understand
or perform the manual process without `cl-phalcon`.

The managed CLI is the recommended path for normal use because it stores
metadata, validates modules, updates conflicts idempotently, and avoids
overwriting CloudLinux's official `phalcon.so`.

Some old manual examples load `psr.so`, `pdo.so`, and `json.so` before
`phalcon4.so`. The CLI uses a narrower version-aware default: Phalcon 4 loads
`psr.so` and `pdo.so` automatically, and Phalcon 5 loads `pdo.so`
automatically. JSON remains an explicit override when a legacy server needs
that exact manual load order. See `docs/dependencies.md`.

```bash
# --------------------------------------------------------
# Install Phalcon41 on CPanel Cloudlinux ALT-PHP74
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v4.1.3 https://github.com/phalcon/cphalcon.git cphalcon-4.1.3;
cd cphalcon-4.1.3/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php74/usr/bin/phpize \
--php-config /opt/alt/php74/usr/bin/php-config
;

mv /opt/alt/php74/usr/lib64/php/modules/phalcon.so /opt/alt/php74/usr/lib64/php/modules/phalcon4.so;
chown root:linksafe /opt/alt/php74/usr/lib64/php/modules/phalcon4.so;
ls -la /opt/alt/php74/usr/lib64/php/modules/phalcon4.so;

# Add phalcon4.ini to load phalcon4.so
echo "
;Enable phalcon4 extension module
extension=psr.so
extension=pdo.so
extension=json.so
extension=phalcon4.so
" > /opt/alt/php74/etc/php.d.all/phalcon4.ini

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon42 on CPanel Cloudlinux ALT-PHP80
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch 4.2.x https://github.com/phalcon/cphalcon.git cphalcon-4.2.x;
cd cphalcon-4.2.x/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php80/usr/bin/phpize \
--php-config /opt/alt/php80/usr/bin/php-config
;

mv /opt/alt/php80/usr/lib64/php/modules/phalcon.so /opt/alt/php80/usr/lib64/php/modules/phalcon4.so;
chown root:linksafe /opt/alt/php80/usr/lib64/php/modules/phalcon4.so;
ls -la /opt/alt/php80/usr/lib64/php/modules/phalcon4.so;

# Add phalcon4.ini to load phalcon4.so
echo "
;Enable phalcon4 extension module
extension=psr.so
extension=pdo.so
extension=json.so
extension=phalcon4.so
" > /opt/alt/php80/etc/php.d.all/phalcon4.ini

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon56 on CPanel Cloudlinux ALT-PHP82
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.6.0 https://github.com/phalcon/cphalcon.git cphalcon-5.6.0;
cd cphalcon-5.6.0/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php82/usr/bin/phpize \
--php-config /opt/alt/php82/usr/bin/php-config
;

mv /opt/alt/php82/usr/lib64/php/modules/phalcon.so /opt/alt/php82/usr/lib64/php/modules/phalcon56.so;
chown root:linksafe /opt/alt/php82/usr/lib64/php/modules/phalcon56.so;
ls -la /opt/alt/php82/usr/lib64/php/modules/phalcon56.so;

# Add phalcon56.ini to load phalcon56.so
echo "
;Enable phalcon56 extension module
extension=phalcon56.so
" > /opt/alt/php82/etc/php.d.all/phalcon56.ini

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon57 on CPanel Cloudlinux ALT-PHP83
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.7.0 https://github.com/phalcon/cphalcon.git cphalcon-5.7.0;
cd cphalcon-5.7.0/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php83/usr/bin/phpize \
--php-config /opt/alt/php83/usr/bin/php-config
;

mv /opt/alt/php83/usr/lib64/php/modules/phalcon.so /opt/alt/php83/usr/lib64/php/modules/phalcon57.so;
chown root:linksafe /opt/alt/php83/usr/lib64/php/modules/phalcon57.so;
ls -la /opt/alt/php83/usr/lib64/php/modules/phalcon57.so;

# Add phalcon57.ini to load phalcon57.so
echo "
;Enable phalcon57 extension module
extension=phalcon57.so
" > /opt/alt/php83/etc/php.d.all/phalcon57.ini
chown root:linksafe /opt/alt/php83/etc/php.d.all/phalcon57.ini

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon59 on CPanel Cloudlinux ALT-PHP82
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.9.3 https://github.com/phalcon/cphalcon.git cphalcon-5.9.3;
cd cphalcon-5.9.3/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php82/usr/bin/phpize \
--php-config /opt/alt/php82/usr/bin/php-config
;

mv /opt/alt/php82/usr/lib64/php/modules/phalcon.so /opt/alt/php82/usr/lib64/php/modules/phalcon59.so;
chown root:linksafe /opt/alt/php82/usr/lib64/php/modules/phalcon59.so;
ls -la /opt/alt/php82/usr/lib64/php/modules/phalcon59.so;

# Add phalcon59.ini to load phalcon59.so
echo "
;Enable phalcon59 extension module
extension=phalcon59.so
" > /opt/alt/php82/etc/php.d.all/phalcon59.ini
chown root:linksafe /opt/alt/php82/etc/php.d.all/phalcon59.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon111
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon59 on CPanel Cloudlinux ALT-PHP83
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.9.3 https://github.com/phalcon/cphalcon.git cphalcon-5.9.3;
cd cphalcon-5.9.3/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php83/usr/bin/phpize \
--php-config /opt/alt/php83/usr/bin/php-config
;

mv /opt/alt/php83/usr/lib64/php/modules/phalcon.so /opt/alt/php83/usr/lib64/php/modules/phalcon59.so;
chown root:linksafe /opt/alt/php83/usr/lib64/php/modules/phalcon59.so;
ls -la /opt/alt/php83/usr/lib64/php/modules/phalcon59.so;

# Add phalcon59.ini to load phalcon59.so
echo "
;Enable phalcon59 extension module
extension=phalcon59.so
" > /opt/alt/php83/etc/php.d.all/phalcon59.ini
chown root:linksafe /opt/alt/php83/etc/php.d.all/phalcon59.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon111
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon59 on CPanel Cloudlinux ALT-PHP84
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.9.3 https://github.com/phalcon/cphalcon.git cphalcon-5.9.3;
cd cphalcon-5.9.3/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php84/usr/bin/phpize \
--php-config /opt/alt/php84/usr/bin/php-config
;

mv /opt/alt/php84/usr/lib64/php/modules/phalcon.so /opt/alt/php84/usr/lib64/php/modules/phalcon59.so;
chown root:linksafe /opt/alt/php84/usr/lib64/php/modules/phalcon59.so;
ls -la /opt/alt/php84/usr/lib64/php/modules/phalcon59.so;

# Add phalcon59.ini to load phalcon59.so
echo "
;Enable phalcon59 extension module
extension=phalcon59.so
" > /opt/alt/php84/etc/php.d.all/phalcon59.ini
chown root:linksafe /opt/alt/php84/etc/php.d.all/phalcon59.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini

# --------------------------------------------------------
# Install Phalcon513 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.13.0 https://github.com/phalcon/cphalcon.git cphalcon-5.13.0;
cd cphalcon-5.13.0/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon513.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon513.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon513.so;

# Add phalcon513.ini to load phalcon513.so
echo "
;Enable phalcon513 extension module
extension=phalcon513.so
" > /opt/alt/php85/etc/php.d.all/phalcon513.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon513.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon514 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.14.1 https://github.com/phalcon/cphalcon.git cphalcon-5.14.1;
cd cphalcon-5.14.1/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;

# Add phalcon514.ini to load phalcon514.so
echo "
;Enable phalcon514 extension module
extension=phalcon514.so
" > /opt/alt/php85/etc/php.d.all/phalcon514.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon514.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon514 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.14.1 https://github.com/phalcon/cphalcon.git cphalcon-5.14.1;
cd cphalcon-5.14.1/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;

# Add phalcon514.ini to load phalcon514.so
echo "
;Enable phalcon514 extension module
extension=phalcon514.so
" > /opt/alt/php85/etc/php.d.all/phalcon514.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon514.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini



# --------------------------------------------------------
# Install Phalcon514 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.14.2 https://github.com/phalcon/cphalcon.git cphalcon-5.14.2;
cd cphalcon-5.14.2/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon514.so;

# Add phalcon514.ini to load phalcon514.so
echo "
;Enable phalcon514 extension module
extension=phalcon514.so
" > /opt/alt/php85/etc/php.d.all/phalcon514.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon514.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513, phalcon514, phalcon515
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon515 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.15.0 https://github.com/phalcon/cphalcon.git cphalcon-5.15.0;
cd cphalcon-5.15.0/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon515.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon515.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon515.so;

# Add phalcon515.ini to load phalcon515.so
echo "
;Enable phalcon515 extension module
extension=phalcon515.so
" > /opt/alt/php85/etc/php.d.all/phalcon515.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon515.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513, phalcon514, phalcon515
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini


# --------------------------------------------------------
# Install Phalcon516 on CPanel Cloudlinux ALT-PHP85
# --------------------------------------------------------
cd ~;
git clone --depth 1 --branch v5.16.0 https://github.com/phalcon/cphalcon.git cphalcon-5.16.0;
cd cphalcon-5.16.0/build/;
export CFLAGS="-march=native -O2 -fomit-frame-pointer"
./install \
--phpize /opt/alt/php85/usr/bin/phpize \
--php-config /opt/alt/php85/usr/bin/php-config
;

mv /opt/alt/php85/usr/lib64/php/modules/phalcon.so /opt/alt/php85/usr/lib64/php/modules/phalcon516.so;
chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon516.so;
ls -la /opt/alt/php85/usr/lib64/php/modules/phalcon516.so;

# Add phalcon516.ini to load phalcon516.so
echo "
;Enable phalcon516 extension module
extension=phalcon516.so
" > /opt/alt/php85/etc/php.d.all/phalcon516.ini
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon516.ini;

# Add conflicting versions
# phalcon, phalcon2, phalcon3, phalcon4, phalcon5, phalcon51, phalcon52, phalcon53, phalcon54, phalcon55, phalcon56, phalcon57, phalcon58, phalcon59, phalcon513, phalcon514, phalcon515, phalcon516
vim /etc/cl.selector/php.extensions.conflicts;

# Rebuild Cagefs
cagefsctl --rebuild-alt-php-ini
```
