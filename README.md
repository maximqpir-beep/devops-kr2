# KR2 variant 2

Flask and Redis counter service for `notes.devops.local`.

The application container listens on port `8002`; Compose publishes it only on
the VM loopback interface. Redis is available only on the private `backend`
network and stores its AOF data in the named `redis_data` volume.

## VM deployment

1. Copy `.env.example` to `.env` on the VM and replace the placeholder with a
   random hexadecimal password of at least 32 characters.
2. Set `.env` mode to `600`.
3. Run `docker compose config --quiet` and `docker compose up -d --build --wait`.
4. Install `nginx/kr2` as `/etc/nginx/sites-available/kr2` after creating the
   dedicated SAN certificate for `notes.devops.local`.
