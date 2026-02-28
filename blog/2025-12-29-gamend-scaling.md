# Gamend - Game Server Scaling

Tutorial on how to scale the game server cluster to multiple instances.

Both the running instance of gamend, which can be found at [https://gamend.appsinacup.com](https://gamend.appsinacup.com) and the [README.md](https://github.com/appsinacup/gamend_starter?tab=readme-ov-file#multi-node-local-deployment) now have information about how to deploy the app at scale.

## Infrastructure

When scaling, the recommended is to use Postgres database and Redis cache:

```sh
+------------------------------+
|   Gamend (App Instance 1)    |
+------------------------------+
    	  |           |
    	  |Database   |Cache
    	  v           v
    +----------+   +-------+
    | Postgres |   | Redis |
    +----------+   +-------+
    	  ^           ^
    	  |Database   |Cache
    	  |           |
+------------------------------+
|   Gamend (App Instance 2)    |
+------------------------------+

# Etc. to n instances
```

## Tutorial (Docker Compose)

1. Clone the [gamend_starter](https://github.com/appsinacup/gamend_starter) repo
2. Run the following:

```sh
docker compose -f docker-compose.multi.yml up --scale app=2
```

This will start 2 instances of the `gamend` app, a Postgres database, Redis cache and a nginx that acts as a load balancer.

```sh
- gamend_starter
  - nginx-1: Ports 4000:80
  - db-1: Ports 5432:5432
  - redis-1: Ports  6379:6379
  - app-1
  - app-2
```

Now, go to the browser to [http://localhost:4000](http://localhost:4000), register with any email and then go to the dev mailbox, at [http://localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox) (Only enabled locally to test, in prod disable it). Accept the registration, then login with magic link. You should now have admin access (first registered user is admin).

### Load Balancer

The nginx load balancer will call into either `app-1` or `app-2`. The gamend server has a cache layer, which can be configured in different ways, but for this it's configured with Redis. The database of choice is Postgres here (for single deployment it can also use SQLite).

### Multilevel Cache

The app uses 2 level caching. First `local in memory`, and then `Redis` (over network). When something is written to the database or read, the cache is updated both locally and distributed. Read more about Multilevel cache here:
- [Nebulex Multilevel Cache](https://hexdocs.pm/nebulex/3.0.0-rc.2/getting-started.html#multilevel-cache)
