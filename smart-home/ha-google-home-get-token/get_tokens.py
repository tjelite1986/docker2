from glocaltokens.client import GLocalAuthenticationTokens
import os
import sys

USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")

try:
    if not USERNAME:
        USERNAME = input("Google-epost: ").strip()
    if not PASSWORD:
        import getpass
        PASSWORD = getpass.getpass("App-lösenord (eller lösenord): ")
except EOFError:
    print('Kör containern i interaktivt läge eller sätt env-variablerna USERNAME och PASSWORD')
    sys.exit(2)

client = GLocalAuthenticationTokens(username=USERNAME, password=PASSWORD)

print("\n[*] Hämtar master token...")
master_token = client.get_master_token()
print(f"[*] Master token: {master_token}")

print("\n[*] Hämtar access token...")
access_token = client.get_access_token()
print(f"[*] Access token: {access_token}")

print("\n[*] Klart.")
