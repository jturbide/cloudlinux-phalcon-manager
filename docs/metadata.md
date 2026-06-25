# Metadata

Install records are stored in:

```text
/var/lib/cloudlinux-phalcon-manager/installs.json
```

The file uses this shape:

```json
{
  "schema_version": 1,
  "updated_at": "2026-06-25T00:00:00Z",
  "installs": [
    {
      "php_slot": "php85",
      "php_version": "8.5.7",
      "php_prefix": "/opt/alt/php85",
      "php_binary": "/opt/alt/php85/usr/bin/php",
      "phpize": "/opt/alt/php85/usr/bin/phpize",
      "php_config": "/opt/alt/php85/usr/bin/php-config",
      "extension_dir": "/opt/alt/php85/usr/lib64/php/modules",
      "phalcon_version": "5.14.2",
      "phalcon_git_ref": "v5.14.2",
      "module_name": "phalcon514.so",
      "ini_path": "/opt/alt/php85/etc/php.d.all/phalcon514.ini",
      "cflags": "-march=native -O2 -fomit-frame-pointer",
      "php_api": "20240924",
      "zend_module_api": "20240924",
      "zend_extension_build": "API420240924,NTS",
      "thread_safety": "disabled",
      "debug_build": "no",
      "source_checkout_path": "/usr/local/src/cloudlinux-phalcon-manager/src/cphalcon-v5.14.2",
      "build_time": "2026-06-25T00:00:00Z",
      "installed_by_tool_version": "0.1.0",
      "sha256": "...",
      "ini_dependencies": []
    }
  ]
}
```

`rebuild-needed` compares the stored record to the current alt-php slot. A
rebuild is required when ABI/build metadata changed, the extension directory
changed, the module is missing, or validation fails.
