![pgpi logo](pgpi.svg)

# pgpi: Postgres Private Investigator

pgpi is like Wireshark for Postgres. It's designed to help monitor, understand and troubleshoot network traffic between a Postgres client and server, proxy or pooler.

> _So why not just use Wireshark?_ Read on: using Wireshark is one of the things pgpi can help with.

pgpi sits between the two parties in a Postgres-protocol exchange, forwarding (and perhaps decrypting and re-encrypting) messages while also parsing and logging them. Its other features are designed around that goal.

> _So it's a tool for mounting MITM attacks?_ Only in the same way that a kitchen knife is "a tool for stabbing people". Securing your Postgres connection from MITM attacks is discussed further below.

### Get started

macOS

```bash
> brew install neondatabase-labs/tools/pgpi
> pgpi --help
```

### Example usage with Neon

```bash
> pgpi --override-auth
listening ...
```

In another terminal, connect to a Neon Postgres URL (adding `.localtest.me` to the host name and removing `&channel_binding=require` from the parameters):

```bash
> psql `postgresql://blah`
psql 'postgresql://neondb_owner:password@ep-old-cell-a234ce68-pooler.eu-central-1.aws.neon.tech.localtest.me/otherdb?sslmode=require'
```


## Postgres connection security

If your connection goes over a public network and you can use pgpi without changing your connection parameters, you have an urgent security problem. pgpi is not the reason for this, though it may help demonstrate it. 

Specifically, note that `sslmode=require` is commonly used but offers approximately zero security, because it does nothing to check who is on the other end of a connection. To properly secure a Postgres connection, you **must** use at least one of these connection options: `channel_binding=require`, `sslrootcert=system`, `sslmode=verify-full`, or (with your own certificate authority) `sslmode=verify-ca`.
