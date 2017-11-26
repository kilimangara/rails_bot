
redis_url = 'redis://rediscloud:1uR2jDm49s0XBHXn@redis-18367.c10.us-east-1-2.ec2.cloud.redislabs.com:18367/0/cache'
ShaurmaBot::Application.config.cache_store = :redis_store, redis_url
ShaurmaBot::Application.config.session_store :redis_store,
                                             redis_server: redis_url