# Push this repo to GitHub

Creates github.com/ttracx/ThoxOS-Mini-Provision (rename owner/repo as needed; if
you change them, update the URLs in README.md and install.sh THOX_REPO default).

```
unzip ThoxOS-Mini-Provision.zip
cd ThoxOS-Mini-Provision

git init -b main
git add .
git commit -m "ThoxOS Mini provisioning: LXDE sub-brand UI, resize fix, hardening (0.1.0)"
git remote add origin https://github.com/ttracx/ThoxOS-Mini-Provision.git
git push -u origin main
```

After the push, the README one-liner works:
```
curl -fsSL https://raw.githubusercontent.com/ttracx/ThoxOS-Mini-Provision/main/install.sh \
  | sudo THOX_ROOT_PW='...' THOX_USER_PW='...' bash
```
