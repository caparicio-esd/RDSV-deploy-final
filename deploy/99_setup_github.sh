ssh-keygen -t ed25519 -C "caparicio@esdmadrid.es"
cat /home/upm/.ssh/id_ed25519.pub
git init
git remote add origin https://github.com/caparicio-esd/RDSV-deploy-final
git config --global user.name "caparicio-esd"
git config --global user.mail "caparicio@esdmadrid.es"
git config --global user.email "caparicio@esdmadrid.es"