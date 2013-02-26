## Environment
# This is the configuration of our `ExpressJS` server.

##### Constant Declaration
SESSION_SECRET = "vyingForVyre"

#### Configure the **NotiVYRE** server
# When using methods such as PUT with a form, we can utilize a hidden input
# named ***_method***, which can be used to alter the HTTP method. To do so
# we first need the ***methodOverride*** middleware, which should be placed below
# ***bodyParser*** so that it can utilize it’s ***req.body*** containing the form values.
#
# The ***bodyParser*** middleware  will parse json request bodies (as well as others),
# and place the result in ***req.body***.
#
# We'll be using the templating language ***EJS*** to render our pages.
module.exports = (notiServer, express, io) ->
	
	notiServer.configure( () ->
		
		notiServer.use(express.favicon("#{__dirname}/../client-notivyre/img/favicon.ico") )
		notiServer.use(express.bodyParser())
		notiServer.use(express.methodOverride())
		
		notiServer.set('views', "#{__dirname}/views")
		notiServer.set('view engine', 'ejs')
		notiServer.set('view options',
			layout: true
		)
		
		notiServer.use(express.cookieParser())
		notiServer.use(express.static("#{__dirname}/../client-notivyre") )
		notiServer.use(express.session({ secret: SESSION_SECRET, store: notiServer.sessionStore }))
		notiServer.use(notiServer.router)
	)
	
	##### Development environment setup
	notiServer.configure('development', () ->
		notiServer.use(express.logger())
		notiServer.use( express.errorHandler( dumpExceptions: true, showStack: true ) )
		
		io.set('transports', ['websocket', 'xhr-polling'])
		io.set('log level', 2)
	)

	##### Production environment setup
	notiServer.configure('production', () ->
		notiServer.use(gzippo.compress())
		notiServer.use(express.errorHandler())
		
		io.enable('browser client minification')
		io.enable('browser client etag')
		io.enable('browser client gzip')
		io.set('log level', 1)
	)
		
	
	return