![pgpi logo](pgpi.svg)

# pgpi: Postgres Private Investigator

**`pgpi` helps monitor, understand and troubleshoot Postgres network traffic: Postgres clients, drivers and [ORMs](https://en.wikipedia.org/wiki/Object%E2%80%93relational_mapping) talking to Postgres servers, proxies and poolers.** Also standby servers talking to their primaries and subscriber servers talking to their publishers.

`pgpi` sits between the two parties in a PostgreSQL-protocol exchange, forwarding messages in both directions while parsing and logging them.

### Why not just use Wireshark? 

Ordinarily [Wireshark](https://www.wireshark.org/) is great for this kind of thing, but using Wireshark is difficult if a connection is SSL/TLS-encrypted. [`SSLKEYLOGFILE`](https://wiki.wireshark.org/TLS#tls-decryption) support was [recently merged into libpq](https://www.postgresql.org/message-id/flat/CAOYmi%2B%3D5GyBKpu7bU4D_xkAnYJTj%3DrMzGaUvHO99-DpNG_YKcw%40mail.gmail.com#afc7fbd9fb2d13959cd97acae8ac8532), but it won’t be available in a release version for some time. And not all Postgres connections use libpq.

To get round this, `pgpi` decrypts and re-encrypts a Postgres connection. It then logs and annotates the messages passing through. Or if you prefer to use Wireshark, `pgpi` can enable that by writing keys to an `SSLKEYLOGFILE` instead.

### Postgres and MITM attacks

If your connection goes over a public network and you can use `pgpi` without changing any connection security options, you have an urgent security problem: you’re vulnerable to [MITM attacks](https://en.wikipedia.org/wiki/Man-in-the-middle_attack). `pgpi` isn’t the cause of the problem, but it can help show it up.

A fully-secure Postgres connection requires at least one of these parameters on the client: `channel_binding=require`, `sslrootcert=system`, `sslmode=verify-full`, or (when issuing certificates via your own certificate authority) `sslmode=verify-ca`. Non-libpq clients and drivers may have other ways to specify these features.

Note that `sslmode=require` is quite widely used but [provides no security against MITM attacks](https://neon.com/blog/postgres-needs-better-connection-security-defaults), because it does nothing to check who’s on the other end of a connection.


## Get started with `pgpi`

On macOS, install `pgpi` via Homebrew tap:

```bash
% brew install neondatabase-labs/tools/pgpi  # TODO: NOT YET IMPLEMENTED
```

Or on any platform, simply download [the `pgpi` script](pgpi) and run it using (ideally) Ruby 3.3 or higher. It has no dependencies beyond the Ruby standard library.


## Example session

```bash
% pgpi
listening ...
```

In a second terminal, connect to and query a Neon Postgres database via `pgpi` by (1) appending `.local.neon.build` to the host name and (2) changing `channel_binding=require` to `channel_binding=disable`:

```bash
% psql 'postgresql://neondb_owner:fake_password@ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.local.neon.build/neondb?sslmode=require&channel_binding=disable'
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
  server name via SNI: ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.local.neon.build
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
        --delete-host-suffix bc.de   Delete a suffix from server hostname provided by client (default: .local.neon.build)
        --listen-port nnnn           Port on which to listen for client connection (default: 5432)
        --connect-port nnnn          Port on which to connect to server (default: 5432)
        --sslmode disabled|prefer|require|verify-ca|verify-full
                                     SSL mode for connection to server (default: prefer)
        --sslrootcert system|/path/to/cert
                                     Root/CA certificate for connection to server (default: none)
        --ssl-negotiation mimic|direct|postgres
                                     SSL negotiation style: mimic client, direct or traditional Postgres (default: mimic)
        --[no-]override-auth         Require password auth from client, do SASL/MD5/password auth with server (default: false)
        --[no-]channel-binding       Enable channel binding for SASL connection to server with --override-auth (default: true)
        --[no-]redact-passwords      Redact password messages in logs (default: false)
        --send-chunking whole|byte   Chunk size for sending Postgres data (default: whole)
        --ssl-cert /path/to/cert     TLS certificate for connection with client (default: generated, self-signed)
        --ssl-key /path/to/key       TLS key for connection with client (default: generated)
        --cert-sig rsa|ecdsa         Specify RSA or ECDSA signature for generated certificate (default: rsa)
        --[no-]deny-client-ssl       Tell client that SSL is not supported (default: false)
        --[no-]log-certs             Log TLS certificates (default: false)
        --log-forwarded none|raw|annotated
                                     Whether and how to log forwarded traffic (default: annotated)
        --[no-]quit-on-hangup        Quit when client or server disconnects, instead of looping (default: false)
        --client-sslkeylogfile /path/to/log
                                     Where to append client traffic TLS decryption data (default: nowhere)
        --server-sslkeylogfile /path/to/log
                                     Where to append server traffic TLS decryption data (default: nowhere)
        --[no-]bw                    Force monochrome output even to TTY (default: auto)

```

What are these options for?


### Getting between your Postgres client and server

#### Remote Postgres + local `pgpi` and client

In many cases you’ll probably run your Postgres client and `pgpi` on the same machine, with the server on a different machine, as in the example above.

When you connect your Postgres client via `pgpi` over TLS, `pgpi` uses [SNI](https://en.wikipedia.org/wiki/Server_Name_Indication) to find out what server hostname you gave the client. `pgpi` tries to forward the connection on to that same hostname, except that it first strips off the suffix `.local.neon.build` if present.

> `local.neon.build` is set up such that every possible subdomain — `*.local.neon.build`, `*.*.local.neon.build`, etc. — resolves to your local machine, `127.0.0.1`.

In the example, `ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech.local.neon.build` is just an alias for your local machine, where `pgpi` is running. `pgpi` then turns that hostname back into the real hostname, `ep-crimson-sound-a8nnh11s.eastus2.azure.neon.tech`, for the onward connection.

It’s also possible to:

* Configure `pgpi` to strip a different domain suffix using the option `--delete-host-suffix .abc.xyz`.

* Specify a fixed server hostname, instead of getting it via SNI from the client, using the `--fixed-host db.blah.xyz` option. This is useful especially for non-TLS client connections, where SNI is unavailable.

#### Local Postgres, `pgpi` and client

If the server is on the same machine as `pgpi` and the client, you’ll want `pgpi` and the Postgres server to listen for connections on different ports.

Use `pgpi`'s `--listen-port` and `--connect-port` options to achieve this. Both `--listen-port` and `--connect-port` default to the standard Postgres port, `5432`.

So if your server is running on port `5432`, you might do:

```bash
pgpi --listen-port 5433
```

And then connect the client via `pgpi` on that port:

```bash
psql 'postgresql://me:mypassword@localhost:5433/mydb'
```

### Security: connection from client

By default, `pgpi` generates a minimal, self-signed TLS certificate on the fly, and does nothing to interfere with the authentication process.

If your Postgres client is using `sslrootcert=system`, `sslmode=verify-full` or `sslmode=verify-ca` you’ll need to either:

1. Downgrade that to `sslmode=require` or lower; or 
2. Supply `pgpi` with a TLS certificate that’s trusted according to `sslrootcert`, plus the corresponding private key, using the `--ssl-cert` and `--ssl-key` options.

If your Postgres client is using `channel_binding=require`, you’ll need to:

1. Downgrade that to `channel_binding=disable`; or
2. Downgrade to `channel_binding=prefer` _and_ use the `--override-auth` option to have `pgpi` perform authorization on the client’s behalf (cleartext, MD5 and SCRAM auth are supported, by requesting the client’s password in cleartext); or
3. Supply `pgpi` with precisely the same certificate and private key the server is using, via the `--ssl-cert` and `--ssl-key` options.


### Security: connection to server

`pgpi` has `--sslmode` and `--sslrootcert` options that work the same as those options to `libpq`. To secure the onward connection to a server with an SSL certificate signed by a public CA, specify `--sslrootcert=system`.


### Logging

By default, `pgpi` logs and annotates all Postgres traffic that passes through. This behaviour can be specified explicitly as `--log-forwarded annotated`.

Alternatives are `--log-forwarded raw`, which logs the data without annotation (it just calls Ruby’s `inspect` on the binary string), or `--log-forwarded none`, which prevents logging. You might use `--log-forwarded none` if you're using `pgpi` to enable the use of Wireshark, for example.

Example log line for `--log-forwarded annotated`:

```text
server -> client: "Z" = ReadyForQuery "\x00\x00\x00\x05" = 5 bytes "I" = idle
```

Equivalent log line for `--log-forwarded raw`:

```text
server -> client: "Z\x00\x00\x00\x05I"
```

Use the `--log-certs` option to log the certificates being used by TLS connections to both client and server.

Use `--redact-passwords` to prevent password messages being logged. When logging annotated messages, only passwords and MD5 hashes themselves are redacted. When logging raw bytes, any message beginning with "p" (which could be a password message) is redacted.

Use `--bw` to suppress colours in TTY output (or `--no-bw` to force colours even for non-TTY output).


### Connection options

The `--ssl-negotiation direct` option tells `pgpi` to initiate a TLS connection to the server immediately, without first sending an SSLRequest message (this is a [new feature in Postgres 17+](https://www.postgresql.org/docs/current/release-17.html#RELEASE-17-LIBPQ) and saves a network round-trip). Specifying `--ssl-negotiation postgres` has the opposite effect. The default is `--ssl-negotiation mimic`, which has `pgpi` do whatever the connecting client did.

The `--no-channel-binding` option removes support for channel binding (SCRAM-SHA-256-PLUS) when authenticating with the server via `--override-auth`.

The `--cert-sig` option specifies the encryption type of the self-signed certificate `pgpi` presents to connecting clients. The default is `--cert-sig rsa`, but `--cert-sig ecdsa` is also supported.

If the `--send-chunking byte` option is given, all traffic is forwarded one single byte at a time in both directions. This is extremely inefficient, but it can smoke out software that doesn’t correctly buffer its TCP/TLS input. The default is `--send-chunking whole`, which forwards as many complete Postgres messages as are available when new data are received.

The `--quit-on-hangup` option causes the script to exit when the first Postgres connection closes, instead of listening for a new connection.


### Using Wireshark

If you prefer to use Wireshark to analyze your Postgres traffic, you can use the `--client-sslkeylogfile` and/or `--server-sslkeylogfile` options to specify files that will have TLS keys (for either side of the connection) appended for use in decryption.

You could also simply use an unencrypted connection on the client side. Use the `--deny-client-ssl` option to have `pgpi` tell connecting clients that TLS is not supported (while still supporting TLS for the onward connection to the server).

If using Wireshark, you might also want to specify `--log-forwarded none`.


### Notes

* Postgres options refer to SSL rather than TLS for historical reasons. `pgpi` options do so for consistency with Postgres. SSL and TLS can be regarded as wholly synonymous here.
* When reading Postgres protocol messages, you’ll see that most are [TLV-encoded](https://en.wikipedia.org/wiki/Type%E2%80%93length%E2%80%93value): they begin with 1 byte for the message’s type and 4 bytes for its length. Note that the 4-byte length value _includes its own length_: for example, it takes the value `4` if no data follows. Length values elsewhere in the protocol typically _do not_ include their own length, however. There is also some apparent inconsistency in whether strings and lists of strings are null-terminated.
* The Postgres protocol has some [helpful documentation](https://www.postgresql.org/docs/current/protocol.html).


### Tests

To tun tests, clone this repo and from the root directory:

* Get the `pg` gem: `gem install pg`
* Ensure Docker is installed and running
* Create a file `tests/.env` containing `DATABASE_URL="postgresql://..."` which must point to a database with a PKI-signed SSL cert (e.g. on Neon)
* Run `tests/test.sh`
* Or to see OpenSSL, Docker and pgpi output alongside test results: `tests/test.sh --verbose`


### License

`pgpi` is released under the [Apache-2.0 license](LICENSE).
