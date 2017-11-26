
redis_url = 'redis://redistogo:baccc2133436ee7fb97eaf32f62a9b97@grouper.redistogo.com:11092/0/cache'
ShaurmaBot::Application.config.cache_store = :redis_store, redis_url
ShaurmaBot::Application.config.session_store :redis_store,
                                             redis_server: redis_url