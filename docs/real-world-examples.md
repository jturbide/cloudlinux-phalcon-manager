# Real-world Examples

These examples assume a root shell on a CloudLinux cPanel server.

## See Which alt-php Slots Exist

```bash
cl-phalcon detect
```

## Install Phalcon 5.16 for PHP 8.5

```bash
cl-phalcon install --php php85 --phalcon 5.16.0 --yes
cl-phalcon validate --php php85 --module phalcon516
```

This writes:

```text
/opt/alt/php85/usr/lib64/php/modules/phalcon516.so
/opt/alt/php85/etc/php.d.all/phalcon516.ini
```

## Install the Same Phalcon Version for Several PHP Versions

```bash
cl-phalcon install --php php82,php83,php84,php85 --phalcon 5.14.2 --yes
cl-phalcon validate
```

Each alt-php slot gets its own compiled module. The tool never copies a module
from one PHP slot to another.

## Legacy Phalcon 4 Application

```bash
cl-phalcon install \
  --php php74 \
  --phalcon 4.1.3 \
  --module phalcon4 \
  --yes
```

For Phalcon 4, `cl-phalcon` writes `extension=psr.so` before
`extension=phalcon4.so` by default. Use `--dependencies psr,pdo,json` only when
you intentionally want the older manual load order.

## After a CloudLinux alt-php Update

Check first:

```bash
cl-phalcon rebuild-needed
```

Apply only the required rebuilds:

```bash
cl-phalcon update --yes
```

Use a dry run when you want to see the plan:

```bash
cl-phalcon --dry-run update
```

## Upgrade a Managed Slot to a Newer Phalcon

Upgrade PHP 8.5 from an older managed module to Phalcon 5.16:

```bash
cl-phalcon --dry-run upgrade --php php85 --phalcon 5.16.0 --module phalcon516
cl-phalcon upgrade --php php85 --phalcon 5.16.0 --module phalcon516 --yes
cl-phalcon validate --php php85 --module phalcon516
```

When the slot has several managed modules, filter the source module explicitly:

```bash
cl-phalcon upgrade \
  --php php85 \
  --from-module phalcon514 \
  --phalcon 5.16.0 \
  --module phalcon516 \
  --yes
```

The old module stays installed. Remove it only after application testing passes:

```bash
cl-phalcon remove --php php85 --module phalcon514 --yes
```

## Update One PHP Slot Only

```bash
cl-phalcon update --php php85 --yes
```

## Keep PHP Selector Conflicts Correct

```bash
cl-phalcon conflicts
cl-phalcon cagefs-rebuild
```

The managed conflict set includes CloudLinux's official `phalcon` selector name
and the versioned modules installed by this tool, so users cannot enable two
different Phalcon extensions at the same time.

## Coexist with CloudLinux's Official Phalcon Package

CloudLinux may provide official Phalcon RPMs. This tool does not remove or
replace those RPMs. It installs custom upstream builds under versioned module
names:

```text
phalcon514.so
phalcon516.so
```

That avoids overwriting the official `phalcon.so` module. The selector conflict
entry then prevents an account from enabling the official `phalcon` extension
and a custom `phalcon516` extension together.

To inspect currently installed CloudLinux Phalcon packages:

```bash
rpm -qa | sort | grep -E '^alt-php[0-9]+.*phalcon'
```

After installing or updating custom modules, refresh selector conflicts:

```bash
cl-phalcon conflicts
cl-phalcon cagefs-rebuild
```
