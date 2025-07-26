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

puts '>> Generating TLS cert ...'
`openssl req -new -newkey rsa:4096 -nodes -out /tmp/ca.csr -keyout /tmp/ca.key -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
openssl x509 -trustout -signkey /tmp/ca.key -days 2 -req -in /tmp/ca.csr -out /tmp/ca.pem
openssl genrsa -out /tmp/client.key 4096
openssl req -new -key /tmp/client.key -out /tmp/client.csr -sha256 -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
openssl x509 -req -days 365 -in /tmp/client.csr -CA /tmp/ca.pem -CAkey /tmp/ca.key -out /tmp/client.cer`

begin
  puts '>> Starting Docker Postgres ...'
  docker_pid = spawn('docker run --rm --name pgpi-postgres-test \
    -p 54320:5432 \
    -e POSTGRES_USER=frodo \
    -e POSTGRES_PASSWORD=friend \
    -v /tmp:/tmp \
    postgres:17 \
    -c ssl=on \
    -c ssl_cert_file=/tmp/client.cer \
    -c ssl_key_file=/tmp/client.key')
  await_port(54320)

  puts '>> Running pgpi ...'
  pgpi_pipe = IO.popen('./pgpi --connect-port 54320 --listen-port 54321')
  await_port(54321)

  puts '>> Connecting ...'
  conn = PG.connect('postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable')

  puts 'Querying ...'
  conn.exec('SELECT now()') { |result| result.each { |row| puts "Result: #{row}" } }
  conn.close

ensure
  puts '>> Cleaning up ...'
  Process.kill('SIGTERM', pgpi_pipe.pid) unless pgpi_pipe.nil?
  Process.kill('SIGTERM', docker_pid) unless docker_pid.nil?
  Process.waitall

  puts pgpi_pipe.read
end
