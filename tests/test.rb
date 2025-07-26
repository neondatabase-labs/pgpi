require 'pg'

# pg server CA/cert
`openssl req -new -newkey rsa:4096 -nodes -out /tmp/ca.csr -keyout /tmp/ca.key -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
openssl x509 -trustout -signkey /tmp/ca.key -days 2 -req -in /tmp/ca.csr -out /tmp/ca.pem
openssl genrsa -out /tmp/client.key 4096
openssl req -new -key /tmp/client.key -out /tmp/client.csr -sha256 -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=Unknown/C=GB"
openssl x509 -req -days 365 -in /tmp/client.csr -CA /tmp/ca.pem -CAkey /tmp/ca.key -out /tmp/client.cer`

begin
  puts 'Starting Docker Postgres ...'
  docker_pid = spawn('docker run --rm --name pgpi-postgres-test \
  -p 54320:5432 \
  -e POSTGRES_USER=frodo \
  -e POSTGRES_PASSWORD=friend \
  -v /tmp:/tmp \
  postgres:17 \
  -c ssl=on \
  -c ssl_cert_file=/tmp/client.cer \
  -c ssl_key_file=/tmp/client.key')

  sleep 5 # TODO: something nicer than this
  puts 'Running pgpi ...'
  pgpi_pid = fork do
    pgpi = IO.popen('./pgpi --connect-port 54320 --listen-port 54321 --quit-on-hangup')
    logs = pgpi.readlines
    puts logs
  end

  sleep 1 # TODO: something nicer than this
  puts 'Connecting ...'
  conn = PG.connect("postgresql://frodo:friend@localhost:54321/frodo?sslmode=require&channel_binding=disable")

  puts 'Querying ...'
  conn.exec('SELECT now()') { |result| result.each { |row| puts row } }
  conn.close

ensure
  puts 'Cleaning up ...'
  Process.wait(pgpi_pid) unless pgpi_pid.nil?
  Process.kill('SIGTERM', docker_pid) unless docker_pid.nil?

  sleep 0.25
  puts 'done'
end