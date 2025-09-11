TEAM=teamA
BASE=/data/teams/$TEAM
sudo mkdir -p $BASE/{work,cache/{pip,uv,poetry/venvs},ssh}

# SSH host keys (persist across recreates)
sudo ssh-keygen -t ed25519 -N '' -f $BASE/ssh/ssh_host_ed25519_key

# Authorized keys for the 'dev' user in the container (uid/gid 1000)
sudo install -m 600 -o 1000 -g 1000 /dev/null $BASE/ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub | sudo tee -a $BASE/ssh/authorized_keys >/dev/null
sudo chmod 700 $BASE/ssh && sudo chown -R 1000:1000 $BASE/ssh
