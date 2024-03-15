# distr.app

![](Public/images/distrapp32.png)
Open source selfhosted iPhone app builds distribution system.

### Launch
- prepare environment variables. See corresponding section below
- `docker compose build` -- builds distr.app from source.
- `docker compose up db -d` -- starts database
- `docker compose run migrate` -- prepares db content
- `docker compose up app -d` -- starts distr.app application

distr.app starts on port 8080, use http proxy such as nginx to dispose app to port 80.

### Stop
- `docker compose down app` -- stops distr.app itself
- `docker compose down` -- stops all images
- `docker compose down -v` -- stops all images and wipes database

### Environment variables
distr.app uses 3 variables to start:
- `DATABASE_NAME`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`

You could copy dot.env.sample file and change username and password as folows:
- `cp dot.env.sample .env`
- `nano .env`
