![pgpi logo](pgpi.svg)

# pgpi: Postgres Private Investigator

**`pgpi` helps monitor, understand and troubleshoot Postgres network traffic: Postgres clients, drivers and [ORMs](https://en.wikipedia.org/wiki/Object%E2%80%93relational_mapping) talking to Postgres servers, proxies and poolers.**

`pgpi` sits between the two parties in a PostgreSQL-protocol exchange, forwarding messages in both directions while parsing and logging them.

### Why not just use Wireshark? 

Ordinarily [Wireshark](https://www.wireshark.org/) is great for this kind of thing, but using Wireshark is difficult if a connection is SSL/TLS-encrypted. [`SSLKEYLOGFILE`](https://wiki.wireshark.org/TLS#tls-decryption) support was [recently merged into libpq](https://www.postgresql.org/message-id/flat/CAOYmi%2B%3D5GyBKpu7bU4D_xkAnYJTj%3DrMzGaUvHO99-DpNG_YKcw%40mail.gmail.com#afc7fbd9fb2d13959cd97acae8ac8532), but it won’t be available in a release version for some time. And not all Postgres connections use libpq.

To get round this, `pgpi` decrypts and re-encrypts a Postgres connection. It then logs and annotates the messages passing through. Or if you prefer to use Wireshark, `pgpi` can enable that by writing keys to an `SSLKEYLOGFILE` instead.

### Postgres and MITM attacks

If your connection goes over a public network and you can use `pgpi` without changing any connection security options, you have an urgent security problem: you’re vulnerable to [MITM attacks](https://en.wikipedia.org/wiki/Man-in-the-middle_attack). `pgpi` didn’t cause the problem, but it can help show it up.

A fully-secure Postgres connection uses at least one of these parameters on the client: `channel_binding=require`, `sslrootcert=system`, `sslmode=verify-full`, or (when issuing certificates via your own certificate authority) `sslmode=verify-ca`. Non-libpq clients and drivers may have other ways to specify these features.

Note that `sslmode=require` is quite widely used but [provides no security against MITM attacks](https://neon.com/blog/postgres-needs-better-connection-security-defaults), because it does nothing to check who’s on the other end of a connection.


## Get started with `pgpi`

On macOS, install `pgpi` via our Homebrew tap:

```bash
% brew install neondatabase-labs/tools/pgpi
```

Or on any platform, simply download the `pgpi` script and run it using (ideally) Ruby 3.3 or higher. It has no dependencies beyond the Ruby standard library.


## Example session

```bash
% pgpi
listening ...
```

In a second terminal, connect to and query a Neon Postgres database via `pgpi` by (1) appending `.localtest.me` to the host name and (2) changing `channel_binding=require` to `channel_binding=disable`:

```bash
% psql 'postgresql://neondb_owner:fake_password@ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.localtest.me/neondb?sslmode=require&channel_binding=disable'
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

Back in the first terminal, see what bytes got exchanged:

```text
% ./pgpi
listening ...
connected at t0 = 2025-07-04 14:28:59 +0100
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
forwarding all later traffic
server -> client: "R" = Authentication "\x00\x00\x00\x2a" = 42 bytes "\x00\x00\x00\x0a" = AuthenticationSASL
  "SCRAM-SHA-256-PLUS\x00" = SASL mechanism
  "SCRAM-SHA-256\x00" = SASL mechanism
  "\x00" = end
^^ 43 bytes forwarded at +0.61s, 0 bytes left in buffer
client -> server: "p" = SASLInitialResponse "\x00\x00\x00\x36" = 54 bytes
  "SCRAM-SHA-256\x00" = selected mechanism "\x00\x00\x00\x20" = 32 bytes follow
  "n,,n=,r=fci+VTkzKrO1kJLK0tL7DEQ1" = SCRAM client-first-message
^^ 55 bytes forwarded at +0.61s, 0 bytes left in buffer
server -> client: "R" = Authentication "\x00\x00\x00\x5c" = 92 bytes "\x00\x00\x00\x0b" = AuthenticationSASLContinue
  "r=fci+VTkzKrO1kJLK0tL7DEQ1Urymgg5N9lizsp07o96IuAEP,s=KBGVGRza5gHefnp4OSU8Gw==,i=4096" = SCRAM server-first-message
^^ 93 bytes forwarded at +0.71s, 0 bytes left in buffer
client -> server: "p" = SASLResponse "\x00\x00\x00\x6c" = 108 bytes
  "c=biws,r=fci+VTkzKrO1kJLK0tL7DEQ1Urymgg5N9lizsp07o96IuAEP,p=PTTYe085GzltpFoYDRDnnJZMPxUKE1Ajrryw6XFY74E=" = SCRAM client-final-message
^^ 109 bytes forwarded at +0.71s, 0 bytes left in buffer
server -> client: "R" = Authentication "\x00\x00\x00\x36" = 54 bytes "\x00\x00\x00\x0c" = AuthenticationSASLFinal
  "v=Oj1crnRpVuFmr693/pTL1lf5+sP7rV0eDW6A/kCTCjg=" = SCRAM server-final-message
server -> client: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x00" = AuthenticationOk
server -> client: "S" = ParameterStatus "\x00\x00\x00\x15" = 21 bytes "is_superuser\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x17" = 23 bytes "DateStyle\x00" = key "ISO, MDY\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x17" = 23 bytes "in_hot_standby\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x23" = 35 bytes "standard_conforming_strings\x00" = key "on\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "integer_datetimes\x00" = key "on\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "server_encoding\x00" = key "UTF8\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x20" = 32 bytes "search_path\x00" = key "\"$user\", public\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1a" = 26 bytes "application_name\x00" = key "psql\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x26" = 38 bytes "default_transaction_read_only\x00" = key "off\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x27" = 39 bytes "session_authorization\x00" = key "neondb_owner\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x18" = 24 bytes "server_version\x00" = key "17.5\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1b" = 27 bytes "IntervalStyle\x00" = key "postgres\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x11" = 17 bytes "TimeZone\x00" = key "GMT\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x19" = 25 bytes "client_encoding\x00" = key "UTF8\x00" = value
server -> client: "S" = ParameterStatus "\x00\x00\x00\x1a" = 26 bytes "scram_iterations\x00" = key "4096\x00" = value
server -> client: "K" = BackendKeyData "\x00\x00\x00\x0c" = 12 bytes "\x8c\xa5\xc2\x9a" = process ID "\xfe\xb8\x7d\x87" = secret key
server -> client: "Z" = ReadyForQuery "\x00\x00\x00\x05" = 5 bytes "I" = idle
^^ 504 bytes forwarded at +1.22s, 0 bytes left in buffer
client -> server: "Q" = Query "\x00\x00\x00\x12" = 18 bytes "SELECT now();\x00" = query
^^ 19 bytes forwarded at +8.62s, 0 bytes left in buffer
server -> client: "T" = RowDescription "\x00\x00\x00\x1c" = 28 bytes "\x00\x01" = 1 columns follow
  "now\x00" = column name "\x00\x00\x00\x00" = table OID: 0 "\x00\x00" = table attrib no: 0 
  "\x00\x00\x04\xa0" = type OID: 1184 "\x00\x08" = type length: 8 "\xff\xff\xff\xff" = type modifier: -1 "\x00\x00" = format: text
server -> client: "D" = DataRow "\x00\x00\x00\x27" = 39 bytes "\x00\x01" = 1 columns follow
  "\x00\x00\x00\x1d" = 29 bytes "2025-07-04 13:29:08.633783+00" = column value
server -> client: "C" = CommandComplete "\x00\x00\x00\x0d" = 13 bytes "SELECT 1\x00" = command tag
server -> client: "Z" = ReadyForQuery "\x00\x00\x00\x05" = 5 bytes "I" = idle
^^ 89 bytes forwarded at +8.73s, 0 bytes left in buffer
client -> server: "X" = Terminate "\x00\x00\x00\x04" = 4 bytes
^^ 5 bytes forwarded at +10.15s, 0 bytes left in buffer
client hung up
connection end

listening ...
```

 (In the terminal, this would be in colour).

## Options

`pgpi --help` lists available options.

```text
% pgpi --help
pgpi -- Postgres Private Investigator
https://github.com/neondatabase-labs/pgpi ++ Copyright 2025 Databricks, Inc. ++ License: Apache 2.0

Usage: pgpi [options]
        --fixed-host a.bc.de         Use a fixed Postgres server hostname (default: via SNI, or 'localhost')
        --delete-host-suffix bc.de   Delete a suffix from server hostname provided by client (default: .localtest.me)
        --listen-port nnnn           Port on which to listen for client connection (default: 5432)
        --connect-port nnnn          Port on which to connect to server (default: 5432)
        --ssl-negotiation mimic|direct|postgres
                                     SSL negotiation style: mimic client, direct (supported by Postgres 17+) or traditional Postgres (default: mimic)
        --[no-]override-auth         Require password auth from client, do SASL/MD5/password auth with server (default: false)
        --[no-]redact-passwords      Redact password messages in logs (default: false)
        --send-chunking whole|byte   Chunk size for sending Postgres data (default: whole)
        --ssl-cert /path/to/cert     TLS certificate for connection with client (default: generated, self-signed)
        --ssl-key /path/to/key       TLS key for connection with client (default: generated)
        --cert-sig rsa|ecdsa         Specify RSA or ECDSA signature for generated certificate (default: rsa)
        --[no-]deny-client-ssl       Tell client that SSL is not supported (default: false)
        --[no-]log-certs             Log TLS certificates (default: false)
        --log-forwarded none|raw|annotated
                                     Whether and how to log forwarded traffic (default: annotated)
        --client-sslkeylogfile /path/to/log
                                     Where to append client traffic TLS decryption data (default: nowhere)
        --server-sslkeylogfile /path/to/log
                                     Where to append server traffic TLS decryption data (default: nowhere)
        --[no-]bw                    Force monochrome output even to TTY (default: auto)
```

What are these options for?


### Getting between your Postgres client and server

#### Remote Postgres + local `pgpi` and client

In most cases you’ll probably run `pgpi` and your Postgres client on the same machine, like in the example above.

When you connect your Postgres client via `pgpi` over TLS, `pgpi` uses [SNI](https://en.wikipedia.org/wiki/Server_Name_Indication) to find out what server hostname you gave the client. `pgpi` tries to forward your connection on to the same hostname, except that it first strips off the suffix `.localtest.me` if present.

> [localtest.me](https://github.com/localtest-dot-me/localtest-dot-me.github.com) is a helpful free service where both the root and every possible subdomain — `localtest.me`, `*.localtest.me`, `*.*.localtest.me`, etc. — resolve to your local machine, `127.0.0.1`.

In the example, `ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.localtest.me` is just an alias for your local machine, where you’re running `pgpi`. But `pgpi` turns that hostname back into the real hostname, `ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech`, for the onward connection.

Alternatives:

* Configure `pgpi` to strip a different domain suffix using the option `--delete-host-suffix .abc.xyz`.

* Specify a fixed server hostname instead of getting it via SNI using the `--fixed-host db.blah.xyz` option. This is useful especially for non-TLS connections.

#### Local Postgres, `pgpi` and client

If the server is on the same machine as `pgpi` and the client, you’ll want instead to have `pgpi` and the server listen on different ports. Use `pgpi`'s `--listen-port` and/or `--connect-port` options to achieve this. Both `--listen-port` and `--connect-port` default to `5432`.

So, if the server is running on standard port `5432`, you might do:

```bash
pgpi --listen-port 5433
```

And then connect the client via `pgpi`:

```bash
psql 'postgresql://user:password@localhost:5433/db'
```

#### Security options


--override-auth
--redact-passwords
--ssl-cert
--ssl-key


### Configuring logging

--log-forwarded
--log-certs
--bw


### Configuring connection options

--deny-client-ssl
--ssl-negotiation
--cert-sig
--send-chunking


### Using Wireshark

--client-sslkeylogfile
--server-sslkeylogfile 


