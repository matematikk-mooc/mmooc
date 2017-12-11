docker run -v /var/log/apache2 -v /opt/canvas-lms/log -v /opt/canvas-lms/tmp/files --name=web-data ubuntu:16.04
docker run -v /var/lib/postgresql/9.5/main --name=db-data ubuntu:16.04
docker run --rm -t -i --env-file=env --user=root --volumes-from=db-data mmooc/db /bin/bash /root/initdb
docker run --env-file=env -d -P --volumes-from=db-data --name=db mmooc/db
docker run --env-file=env -d -P --name=cache mmooc/cache
docker run --rm --env-file=env -w /opt/canvas-lms --link=db:db --link=cache:cache mmooc/canvas bundle exec rake db:initial_setup >&2 2> init_schema.1.txt
docker run --rm --env-file=env -w /opt/canvas-lms --link=db:db --link=cache:cache mmooc/canvas bundle exec rake db:initial_setup >&2 2> init_schema.2.txt
docker run --env-file=env -d -P --volumes-from=web-data --link db:db --link cache:cache --name=web mmooc/canvas
docker_run mmooc/haproxy haproxy "--link web:web1 -p 443:443 -p 80:80"
docker run --env-file=env -d -P "--link --name=haproxy mmooc/haproxy
docker run --rm -t -i --env-file=env --user=root --volumes-from=db-data mmooc/db /bin/bash /root/initdb
docker run --rm --env-file=env -w /opt/canvas-lms --link=db:db --link=cache:cache mmooc/canvas bundle exec rake db:initial_setup >&2 2> init_schema.1.txt
docker run --rm --env-file=env -w /opt/canvas-lms --link=db:db --link=cache:cache mmooc/canvas bundle exec rake db:initial_setup >&2 2> init_schema.2.txt
docker run --env-file=env -d -P --link web:web1 -p 443:443 -p 80:80 --name=haproxy mmooc/haproxy
