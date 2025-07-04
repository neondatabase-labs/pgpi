![pgpi logo](pgpi.svg)

# pgpi: Postgres Private Investigator

pgpi is like Wireshark for Postgres. It's designed to help monitor, understand and troubleshoot network traffic between Postgres clients, servers, proxies and poolers.

> _So why not just use Wireshark?_ Read on: using Wireshark is one of the things pgpi can help with.

pgpi sits between the two parties in a Postgres-protocol exchange, forwarding (and perhaps decrypting and re-encrypting) messages while also parsing and logging them. Its other features are designed around that goal.

> _So it's a tool for mounting MITM attacks?_ Only in the same way that a kitchen knife is "a tool for stabbing people". Securing your Postgres connection from MITM attacks is discussed below.

### Get started

On macOS, you can use a Homebrew tap to install:

```bash
% brew install neondatabase-labs/tools/pgpi
```

Or, on macOS and elsewhere, simply download the `pgpi` Ruby script from this repo and run it using (ideally) Ruby 3.3 or higher.

### Example usage

```bash
% pgpi --override-auth
listening ...
```

In another terminal, connect to a Neon Postgres database. But first, append `.localtest.me` to the host name and delete `&channel_binding=require` from the parameters. Then run a query:

```bash
% psql 'postgresql://neondb_owner:fake_password@ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.localtest.me/neondb?sslmode=require'
psql (17.5 (Homebrew))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

neondb=> SELECT now();
              now              
-------------------------------
 2025-07-02 11:51:01.721628+00
(1 row)

neondb=> \q
%
```

Back in the first terminal, let's see what data got sent:

```text
% pgpi --override-auth
listening ...
connected at t0 = 2025-07-02 12:49:41 +0100
client -> script: "\x00\x00\x00\x08\x04\xd2\x16\x2f" = SSLRequest
script -> client: "S" = SSL supported
TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with client
  server name via SNI: ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.localtest.me
client -> script: "\x00\x00\x00\x56" = 86 bytes of startup message "\x00\x03\x00\x00" = protocol version
  "user\x00" = key "neondb_owner\x00" = value
  "database\x00" = key "neondb\x00" = value
  "application_name\x00" = key "psql\x00" = value
  "client_encoding\x00" = key "UTF8\x00" = value
  "\x00" = end
connecting to Postgres server: ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech
script -> server: "\x00\x00\x00\x08\x04\xd2\x16\x2f" = SSLRequest
server -> script: "S" = SSL supported
TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server
forwarding client startup message to server
script -> server: "\x00\x00\x00\x56" = 86 bytes of startup message "\x00\x03\x00\x00" = protocol version
  "user\x00" = key "neondb_owner\x00" = value
  "database\x00" = key "neondb\x00" = value
  "application_name\x00" = key "psql\x00" = value
  "client_encoding\x00" = key "UTF8\x00" = value
  "\x00" = end
now overriding authentication
server -> script: "R" = Authentication "\x00\x00\x00\x2a" = 42 bytes "\x00\x00\x00\x0a" = AuthenticationSASL
  "SCRAM-SHA-256-PLUS\x00" = SASL mechanism
  "SCRAM-SHA-256\x00" = SASL mechanism
  "\x00" = end
script -> client: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x03" = AuthenticationCleartextPassword
client -> script: "p" = PasswordMessage (plaintext) "\x00\x00\x00\x11" = 17 bytes "fake_password\x00" = password
script -> server: "p" = SASLInitialResponse "\x00\x00\x00\x65" = 101 bytes
  "SCRAM-SHA-256-PLUS\x00" = selected mechanism "\x00\x00\x00\x4a" = 74 bytes follow
  "p=tls-server-end-point,,n=*,r=N4HHGh4Sz16hBjt0c4qkHiUffZ8l5tKp8Zl+zXv+B4I=" = SCRAM client-first-message
server -> script: "R" = Authentication "\x00\x00\x00\x70" = 112 bytes "\x00\x00\x00\x0b" = AuthenticationSASLContinue
  "r=N4HHGh4Sz16hBjt0c4qkHiUffZ8l5tKp8Zl+zXv+B4I=s6mhJXdFDPSOo7gCcH5WUqWl,s=KBGVGRza5gHefnp4OSU8Gw==,i=4096" = SCRAM server-first-message
script -> server: "p" = SASLResponse "\x00\x00\x00\xc8" = 200 bytes
  "c=cD10bHMtc2VydmVyLWVuZC1wb2ludCwsxQRRKokHig6Isp8iF0t8xEKjlgyFC21ZMTjMiULP0Vg=,r=N4HHGh4Sz16hBjt0c4qkHiUffZ8l5tKp8Zl+zXv+B4I=s6mhJXdFDPSOo7gCcH5WUqWl,p=FV9muy0Z2Pn/G3iXumwkYQTew53M4uE5VJTM7WOhdro=" = SCRAM client-final-message
server -> script: "R" = Authentication "\x00\x00\x00\x36" = 54 bytes "\x00\x00\x00\x0c" = AuthenticationSASLFinal
  "v=FilAMgQewd4pEPErLdOw2MVFPNIpuA8bmtBgiUHD0bE=" = SCRAM server-final-message
forwarding all later traffic
server -> client: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x00" = AuthenticationOk
server -> client: "S" = ParameterStatus "\x00\x00\x00\x17" = 23 bytes "in_hot_standby\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "server_encoding\x00" = key "UTF8\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "integer_datetimes\x00" = key "on\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "client_encoding\x00" = key "UTF8\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1b" = 27 bytes "IntervalStyle\x00" = key "postgres\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1a" = 26 bytes "scram_iterations\x00" = key "4096\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x23" = 35 bytes "standard_conforming_strings\x00" = key "on\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x17" = 23 bytes "DateStyle\x00" = key "ISO, MDY\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x11" = 17 bytes "TimeZone\x00" = key "GMT\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x15" = 21 bytes "is_superuser\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x26" = 38 bytes "default_transaction_read_only\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x27" = 39 bytes "session_authorization\x00" = key "neondb_owner\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x18" = 24 bytes "server_version\x00" = key "17.5\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x20" = 32 bytes "search_path\x00" = key "\"$user\", public\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1a" = 26 bytes "application_name\x00" = key "psql\x00" = value
server -> client: "K" = BackendKeyData "\x00\x00\x00\x0c" = 12 bytes "\xb1\x51\x55\x0b" = process ID "\xa6\x82\x75\x4e" = secret key
server -> client: "Z" = ReadyForQuery "\x00\x00\x00\x05" = 5 bytes "I" = idle
^^ 449 bytes forwarded at +0.8s, 0 bytes left in buffer
client -> server: "Q" = Query "\x00\x00\x00\x12" = 18 bytes "SELECT now();\x00" = query
^^ 19 bytes forwarded at +80.46s, 0 bytes left in buffer
server -> client: "T" = RowDescription "\x00\x00\x00\x1c" = 28 bytes "\x00\x01" = 1 columns follow
  "now\x00" = column name "\x00\x00\x00\x00" = table OID: 0 "\x00\x00" = table attrib no: 0 "\x00\x00\x04\xa0" = type OID: 1184 "\x00\x08" = type length: 8 "\xff\xff\xff\xff" = type modifier: -1 "\x00\x00" = format: text
server -> client: "D" = DataRow "\x00\x00\x00\x27" = 39 bytes "\x00\x01" = 1 columns follow
  "\x00\x00\x00\x1d" = 29 bytes "2025-07-02 11:51:01.721628+00" = column value
server -> client: "C" = CommandComplete "\x00\x00\x00\x0d" = 13 bytes "SELECT 1\x00" = command tag
server -> client: "Z" = ReadyForQuery "\x00\x00\x00\x05" = 5 bytes "I" = idle
^^ 89 bytes forwarded at +80.58s, 0 bytes left in buffer
client -> server: "X" = Terminate "\x00\x00\x00\x04" = 4 bytes
^^ 5 bytes forwarded at +84.72s, 0 bytes left in buffer
client hung up
connection end

listening ...
```


## Postgres connection security

If your connection goes over a public network and you can use pgpi without changing your connection parameters, you have an urgent security problem. pgpi is not the reason for this, though it may help demonstrate it. 

Specifically, note that `sslmode=require` is commonly used but offers approximately zero security, because it does nothing to check who is on the other end of a connection. To properly secure a Postgres connection, you **must** use at least one of these connection options: `channel_binding=require`, `sslrootcert=system`, `sslmode=verify-full`, or (with your own certificate authority) `sslmode=verify-ca`.

