require 'pg'
require 'socket'
require 'timeout'

QUIET = ARGV[0] != "--verbose"
$redir = QUIET ? '> /dev/null 2>&1' : ''
$spawn_opts = QUIET ? { :err => File::NULL, :out => File::NULL } : {}

puts '>> Generating TLS cert ...'
`openssl req -new -newkey rsa:4096 -nodes -out /tmp/ca.csr -keyout /tmp/ca.key -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB" #{$redir}
openssl x509 -trustout -signkey /tmp/ca.key -days 2 -req -in /tmp/ca.csr -out /tmp/ca.pem #{$redir}
openssl genrsa -out /tmp/client.key 4096 #{$redir}
openssl req -quiet -new -key /tmp/client.key -out /tmp/client.csr -sha256 -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB" #{$redir}
openssl x509 -req -days 365 -in /tmp/client.csr -CA /tmp/ca.pem -CAkey /tmp/ca.key -out /tmp/client.cer #{$redir}`

def await_port(port)
  Timeout::timeout(30) do
    begin
      TCPSocket.new('localhost', port).close
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      sleep 0.1
      retry
    end
  end
end

def with_postgres(auth_method = 'scram-sha-256', port = 54320)
  puts ">> Starting Docker Postgres (auth: #{auth_method}, port: #{port}) ..."
  docker_pid = spawn("docker run --rm --name pgpi-postgres-test \
    -p #{port}:5432 \
    -e POSTGRES_USER=frodo \
    -e POSTGRES_PASSWORD=friend \
    -e POSTGRES_HOST_AUTH_METHOD=#{auth_method} \
    #{auth_method == 'md5' ? '-e POSTGRES_INITDB_ARGS="--auth-local=md5"' : ''} \
    -v /tmp:/tmp \
    postgres:17 \
    -c ssl=on \
    -c ssl_cert_file=/tmp/client.cer \
    -c ssl_key_file=/tmp/client.key", **$spawn_opts)

  await_port(port)
  sleep 1 # for additional setup tasks to complete
  yield

ensure
  puts '>> Stopping Docker Postgres ...'
  unless docker_pid.nil?
    Process.kill('SIGTERM', docker_pid)
    Process.wait(docker_pid)
  end
end

def with_pgpi(args = '', listen_port = 54321, connect_port = 54320)
  killed = false
  pgpi_pipe = IO.popen("./pgpi --connect-port #{connect_port} --listen-port #{listen_port} #{args}")
  await_port(listen_port)
  block_result = yield

  Process.kill('SIGTERM', pgpi_pipe.pid)
  Process.wait(pgpi_pipe.pid)
  killed = true
  pgpi_log = pgpi_pipe.read
  pgpi_pipe.close
  [block_result, pgpi_log]

ensure
  unless killed
    Process.kill('SIGTERM', pgpi_pipe.pid)
    Process.wait(pgpi_pipe.pid)
  end
end

def do_test_query(connection_string)
  PG.connect(connection_string) do |conn|
    conn.exec("SELECT 'xyz' AS col") do |result|
      result.each do |row|
        return row == { "col" => "xyz" }
      end
    end
  end
end

$passes = $fails = 0

def do_test(desc)
  result = yield
rescue => err
  result = err
ensure
  is_err = result.kind_of?(Exception)
  puts result.full_message if is_err

  failed = is_err || !result
  $passes += 1 unless failed
  $fails += 1 if failed

  puts "#{failed ? "\033[31mFAIL" : "\033[32mPASS"}\033[0m  \033[1m#{desc}\033[0m"
end

def contains(haystack, needle, expected = true)
  return true if haystack.include?(needle) == expected
  puts haystack
  false
end

begin
  with_postgres do

    do_test("basic connection") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("strip .localtest.me") do
      result, _ = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost.localtest.me:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("--delete-host-suffix") do
      result, _ = with_pgpi("--delete-host-suffix .127-0-0-1.sslip.io") do
        do_test_query('postgresql://frodo:friend@localhost.127-0-0-1.sslip.io:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("--fixed-host") do
      result, _ = with_pgpi("--fixed-host localhost") do
        do_test_query('postgresql://frodo:friend@imaginary.server.localtest.me:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("--listen-port") do
      result, pgpi_log = with_pgpi('', 65432) do
        do_test_query('postgresql://frodo:friend@localhost:65432/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("--ssl-negotiation postgres") do
      result, pgpi_log = with_pgpi("--ssl-negotiation postgres") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, "direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server", false)
    end

    do_test("--ssl-negotiation direct") do
      result, pgpi_log = with_pgpi("--ssl-negotiation direct") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, "direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

    do_test("--ssl-negotiation mimic, where client uses Postgres SSL negotiation") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable&sslnegotiation=postgres')
      end
      result && contains(pgpi_log, "direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server", false)
    end

    do_test("--ssl-negotiation mimic, where client uses direct SSL connection") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable&sslnegotiation=direct')
      end
      result && contains(pgpi_log, "direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

    do_test("--override-auth using SCRAM-SHA-256") do
      result, pgpi_log = with_pgpi("--override-auth") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, 'now overriding authentication' + "\n" +
                                   'server -> script: "R" = Authentication "\x00\x00\x00\x2a" = 42 bytes "\x00\x00\x00\x0a" = AuthenticationSASL')
    end

    do_test("--override-auth logs password") do
      result, pgpi_log = with_pgpi("--override-auth") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, 'client -> script: "p" = PasswordMessage (cleartext) "\x00\x00\x00\x0b" = 11 bytes "friend\x00" = password')
    end

    do_test("--override-auth with --redact-passwords") do
      result, pgpi_log = with_pgpi("--override-auth --redact-passwords") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, 'client -> script: "p" = PasswordMessage (cleartext) "\x00\x00\x00\x0b" = 11 bytes [redacted] = password')
    end

    do_test("--override-auth with --redact-passwords and --log-forwarded raw") do
      result, pgpi_log = with_pgpi("--override-auth --redact-passwords --log-forwarded raw") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, 'client -> script: [password message redacted]' + "\n" +
                                   'script -> server: [password message redacted]')
    end

    do_test("--send-chunking byte") do
      result, pgpi_log = with_pgpi("--send-chunking byte") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      # would be nice to actually test byte-by-byte sending here, but for now let's just check log output
      result && contains(pgpi_log, 'bytes forwarded one by one at')
    end

    do_test("--ssl-cert and --ssl-key matching server to enable channel binding)") do
      result, pgpi_log = with_pgpi("--ssl-cert /tmp/client.cer --ssl-key /tmp/client.key") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=require')
      end
      result && contains(pgpi_log, 'client -> server: "p" = SASLInitialResponse "\x00\x00\x00\x50" = 80 bytes' + "\n" +
                                   '  "SCRAM-SHA-256-PLUS\x00" = selected mechanism')
    end

    do_test("ECDSA generated cert") do
      result, pgpi_log = with_pgpi("--cert-sig ecdsa") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && contains(pgpi_log, 'xxx')
    end

  end

  # additional --override-auth tests

  with_postgres('trust') do
    do_test("trust auth") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'forwarding all later traffic' + "\n" +
                                   'server -> client: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x00" = AuthenticationOk')
    end

    do_test("--override-auth + trust auth") do
      result, pgpi_log = with_pgpi("--override-auth") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'now overriding authentication' + "\n" +
                                   'server -> script: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x00" = AuthenticationOk')
    end
  end

  with_postgres('password') do
    do_test("cleartext password auth") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'forwarding all later traffic' + "\n" +
                                   'server -> client: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x03" = AuthenticationCleartextPassword')
    end

    do_test("--redact-passwords + cleartext password auth") do
      result, pgpi_log = with_pgpi("--redact-passwords") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'client -> server: "p" = PasswordMessage (cleartext) "\x00\x00\x00\x0b" = 11 bytes [redacted] = password')
    end

    do_test("--override-auth + cleartext password auth") do
      result, pgpi_log = with_pgpi("--override-auth") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'now overriding authentication' + "\n" +
                                   'server -> script: "R" = Authentication "\x00\x00\x00\x08" = 8 bytes "\x00\x00\x00\x03" = AuthenticationCleartextPassword')
    end

    do_test("--override-auth + --redact-passwords + cleartext password auth") do
      result, pgpi_log = with_pgpi("--override-auth --redact-passwords") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'client -> script: "p" = PasswordMessage (cleartext) "\x00\x00\x00\x0b" = 11 bytes [redacted] = password' + "\n" +
                                   'script -> server: "p" = PasswordMessage (cleartext) "\x00\x00\x00\x0b" = 11 bytes [redacted] = password')
    end
  end

  with_postgres('md5') do
    do_test("MD5 auth") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'forwarding all later traffic' + "\n" +
                                   'server -> client: "R" = Authentication "\x00\x00\x00\x0c" = 12 bytes "\x00\x00\x00\x05" = AuthenticationMD5Password')
    end

    do_test("--override-auth + MD5 auth") do
      result, pgpi_log = with_pgpi("--override-auth") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require')
      end
      result && contains(pgpi_log, 'now overriding authentication' + "\n" +
                                   'server -> script: "R" = Authentication "\x00\x00\x00\x0c" = 12 bytes "\x00\x00\x00\x05" = AuthenticationMD5Password')
    end
  end

ensure
  Process.waitall
  puts "\033[1m#{$passes} passed, #{$fails} failed\033[0m"
  exit($fails == 0)
end
