#!/bin/bash
# Lägg till samba-användare om den inte redan finns
if ! pdbedit -L | grep -q "^${SAMBA_USER}:"; then
    (echo "${SAMBA_PASS}"; echo "${SAMBA_PASS}") | smbpasswd -a -s "${SAMBA_USER}"
    echo "Samba-användare ${SAMBA_USER} skapad."
fi
