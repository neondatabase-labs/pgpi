require 'pg'
require 'socket'
require 'timeout'

def await_port(port)
  Timeout::timeout(30) do
    begin
      TCPSocket.new('localhost', port).close
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      sleep 0.5
      retry
    end
  end
end

def with_postgres(port = 54320)
  puts '>> Generating TLS cert ...'
  `openssl req -quiet -new -newkey rsa:4096 -nodes -out /tmp/ca.csr -keyout /tmp/ca.key -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
  openssl x509 -trustout -signkey /tmp/ca.key -days 2 -req -in /tmp/ca.csr -out /tmp/ca.pem
  openssl genrsa -out /tmp/client.key 4096
  openssl req -quiet -new -key /tmp/client.key -out /tmp/client.csr -sha256 -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
  openssl x509 -req -days 365 -in /tmp/client.csr -CA /tmp/ca.pem -CAkey /tmp/ca.key -out /tmp/client.cer`

  puts '>> Starting Docker Postgres ...'
  docker_pid = spawn("docker run --rm --name pgpi-postgres-test \
    -p #{port}:5432 \
    -e POSTGRES_USER=frodo \
    -e POSTGRES_PASSWORD=friend \
    -v /tmp:/tmp \
    postgres:17 \
    -c ssl=on \
    -c ssl_cert_file=/tmp/client.cer \
    -c ssl_key_file=/tmp/client.key")

  await_port(port)
  yield

ensure
  puts '>> Stopping Docker Postgres ...'
  Process.kill('SIGTERM', docker_pid) unless docker_pid.nil?
end

def with_pgpi(args = '', listen_port = 54321, connect_port = 54320)
  unkilled = true
  pgpi_pipe = IO.popen("./pgpi --connect-port #{connect_port} --listen-port #{listen_port} #{args}")
  await_port(listen_port)
  block_result = yield

  Process.kill('SIGTERM', pgpi_pipe.pid)
  unkilled = false
  pgpi_log = pgpi_pipe.read
  pgpi_pipe.close
  [block_result, pgpi_log]

ensure
  Process.kill('SIGTERM', pgpi_pipe.pid) if unkilled
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

begin
  with_postgres do

    # === start tests ===

    do_test("make and log a basic connection") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && pgpi_log.include?('client -> server: "X" = Terminate "\x00\x00\x00\x04" = 4 bytes')
    end

    do_test("strips .localtest.me") do
      result, _ = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost.localtest.me:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("honours --delete-host-suffix") do
      result, _ = with_pgpi("--delete-host-suffix .127-0-0-1.sslip.io") do
        do_test_query('postgresql://frodo:friend@localhost.127-0-0-1.sslip.io:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("honours --fixed-host") do
      result, _ = with_pgpi("--fixed-host localhost") do
        do_test_query('postgresql://frodo:friend@imaginary.server.localtest.me:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("honours --listen-port") do
      result, pgpi_log = with_pgpi('', 65432) do
        do_test_query('postgresql://frodo:friend@localhost:65432/frodo?sslmode=require&channel_binding=disable')
      end
      result
    end

    do_test("--ssl-negotiation postgres") do
      result, pgpi_log = with_pgpi("--ssl-negotiation postgres") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && !pgpi_log.include?("direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

    do_test("--ssl-negotiation direct") do
      result, pgpi_log = with_pgpi("--ssl-negotiation direct") do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')
      end
      result && pgpi_log.include?("direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

    do_test("--ssl-negotiation mimic (postgres)") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable&sslnegotiation=postgres')
      end
      result && !pgpi_log.include?("direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

    do_test("--ssl-negotiation mimic (direct)") do
      result, pgpi_log = with_pgpi do
        do_test_query('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable&sslnegotiation=direct')
      end
      result && pgpi_log.include?("direct TLSv1.3/TLS_AES_256_GCM_SHA384 connection established with server")
    end

  end
ensure
  Process.waitall
  puts "\033[1m#{$passes} passed, #{$fails} failed\033[0m"
  exit($fails == 0)
end
