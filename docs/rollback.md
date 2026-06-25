# Rollback

`cl-phalcon upgrade` intentionally keeps the old module installed. The safest
rollback is usually to switch the account back to the old module through PHP
Selector, then validate the application.

## PHP Selector Rollback

1. Keep both modules installed:

   ```text
   phalcon514.so
   phalcon516.so
   ```

2. Ensure conflicts are current:

   ```bash
   cl-phalcon conflicts
   cl-phalcon cagefs-rebuild
   ```

3. In PHP Selector, disable the newer module and enable the older known-good
   module.

4. Validate the site or application.

## File Backup Rollback

Before replacing a module or ini file, the tool creates timestamped backups
beside the original file:

```text
phalcon516.so.bak.YYYYMMDDHHMMSS
phalcon516.ini.bak.YYYYMMDDHHMMSS
```

If a file-level rollback is required:

```bash
cp -p /opt/alt/php85/usr/lib64/php/modules/phalcon516.so.bak.YYYYMMDDHHMMSS \
  /opt/alt/php85/usr/lib64/php/modules/phalcon516.so

cp -p /opt/alt/php85/etc/php.d.all/phalcon516.ini.bak.YYYYMMDDHHMMSS \
  /opt/alt/php85/etc/php.d.all/phalcon516.ini

chown root:linksafe /opt/alt/php85/usr/lib64/php/modules/phalcon516.so
chown root:linksafe /opt/alt/php85/etc/php.d.all/phalcon516.ini
cl-phalcon cagefs-rebuild
cl-phalcon validate --php php85 --module phalcon516
```

## Removing an Old Module

Remove old modules only after the new module has been validated:

```bash
cl-phalcon remove --php php85 --module phalcon514 --yes
```
