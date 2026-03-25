#!/bin/bash
set -e

# Skapa användare (om den inte redan finns)
id ${SFTP_USER} &>/dev/null || adduser -D -s /bin/false ${SFTP_USER}
echo "${SFTP_USER}:${SFTP_PASS}" | chpasswd

# Sätt rätt ägare på hemkatalogen (krävs för chroot)
chown root:root /home/${SFTP_USER}
chmod 755 /home/${SFTP_USER}

# Skapa sshd_config
cat > /etc/ssh/sshd_config << EOF
Port 22
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
Subsystem sftp internal-sftp
Match User ${SFTP_USER}
    ChrootDirectory /home/${SFTP_USER}
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

exec /usr/sbin/sshd -D -e
