#### Module Dependencies
# * [Redis](https://github.com/mranney/node_redis) (NoSQL storage)
# There's some handy documentation [here](http://redis.io/commands) that descibes what functions are
# available for `Redis`.
redis = require 'redis'

# Constants
DNS =
	BLANCA:			"172.16.5.25"
	BLANCA_REDIS:	"172.16.9.10"
	GARY:			"172.16.8.28"
	MATT:			"172.16.5.154"
	LOCALHOST:		"127.0.0.1"
REDIS =
	HOST: DNS.BLANCA_REDIS
	PORT_NO: "6379"

# Define the `redis` object that will be exported to our NotiServer app.
defineRedis = (express, fn) ->
	redisConfig =
		RedisStore: require('connect-redis')(express)
	
	redisConfig.sessionStore = new redisConfig.RedisStore(
		host: REDIS.HOST,
		port: REDIS.PORT_NO
	)
	
	# Map the native `redis.createClient` function to our internal redis manager with custom port and host.
	redisConfig.createClient = () ->
		return redis.createClient(REDIS.PORT_NO, REDIS.HOST)
	
	fn(redisConfig);
	
	return

exports.defineRedis = defineRedis