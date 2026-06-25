# Production Readiness Checklist

Before using `cl-phalcon` on a production CloudLinux cPanel server:

1. Review the compatibility grid.

   ```bash
   less docs/compatibility-grid.md
   ```

2. Run preflight checks.

   ```bash
   cl-phalcon doctor
   ```

3. Detect alt-php slots.

   ```bash
   cl-phalcon detect
   ```

4. Dry-run the intended install or upgrade.

   ```bash
   cl-phalcon --dry-run install --php php85 --phalcon 5.16.0
   cl-phalcon --dry-run upgrade --php php85 --phalcon 5.16.0
   ```

5. Install or upgrade with `--yes` only after the dry run looks correct.

6. Validate loaded modules.

   ```bash
   cl-phalcon validate
   ```

7. Refresh selector conflicts and CageFS.

   ```bash
   cl-phalcon conflicts
   cl-phalcon cagefs-rebuild
   ```

8. Confirm PHP Selector shows only one selectable Phalcon module at a time for
   a user account.

9. Keep the old module installed until application testing passes.

10. Remove old modules explicitly only after rollback is no longer needed.

    ```bash
    cl-phalcon remove --php php85 --module phalcon514 --yes
    ```

## After CloudLinux PHP Updates

Use:

```bash
cl-phalcon rebuild-needed
cl-phalcon update --yes
```

`update` rebuilds only managed installs that actually need it. Normal PHP patch
updates should not trigger a rebuild when ABI/build metadata is unchanged.
