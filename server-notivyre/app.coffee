## App
# **NotiVYRE** is the first installment of the [Vying for VYRE](http://onbrand.vyre.com/blog/detail/item31154/Welcome-2012,-a-year-of-innovation-at-VYRE)
# competition. The following documentation is generated from
# source using [Docco](http://jashkenas.github.com/docco/)
# and [Pygments](http://pygments.org/) and the [Markdown](http://daringfireball.net/projects/markdown/syntax)
# language.
#
# The code is written in [CoffeeScript](http://coffeescript.org/).

#### Module Dependencies
# * [ExpressJS](http://expressjs.com/) (server framework)
# * [FS](http://nodejs.org/api/fs.html) (NodeJS file services)
# * [Socket.io](http://socket.io/) (websocket framework)
# * [EJS](http://embeddedjs.com/) (templating language)
# * [Connect-Redis](https://github.com/visionmedia/connect-redis) (redis store connectivity)
# * [Gzippo](http://tomg.co/gzippo) (gzipping)
express = require 'express'
fs = require 'fs'
io = require 'socket.io'
ejs = require 'ejs'
gzippo = require 'gzippo'
exec = require('child_process').exec

#### Initialisation
# Server creation and `WebSockets` listener on the notiServer, `ExpressJS`, app.
notiServer = module.exports = express.createServer()
io = module.exports = io.listen(notiServer)

PORT_NO = 80

# Include configuration scripts
require('./environment')(notiServer, express, io)
require('./routes')(notiServer)

redis = require('./redis')
redis.defineRedis(express, ( redisConfig ) ->
	notiServer.redis = {}
	for config of redisConfig
		notiServer.redis[config] = redisConfig[config]
		
	return
)


require('./sockets')(notiServer, express, io, (fn) ->
	notiServer.getSockets = fn
)


#### Start the server
# Check if the app is running as the top-level module
# and start it up.
if not module.parent
	# Generate Docco documentation and copy it to the client for viewing on the server
	exec("docco ./*.coffee", (error, stdout, stderr) ->
		exec("cp -r ./docs/ ../client-notivyre/docs/")
		return
	)
	notiServer.listen(PORT_NO)
	console.log("Express server listening on port #{notiServer.address().port}, environment: #{notiServer.settings.env}")
	console.log("Using Express #{express.version}, EJS #{ejs.version}\n------------------------------------------------")
