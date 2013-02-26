## Routes
# The router script is responsible for handling all
# the `get` and `post` requests made to the server and
# handling the request, response, authentication, data
# and template rendering.

##### Constant Declaration
SITE_TITLE = "NotiVYRE Monitor"

##### Export all routes
module.exports = (notiServer) ->
#### Pages
# These pages will be automatically generated on site load using
# the above `RouteManager`.
	Pages =
		sockets:
			name: 'sockets'
			prettyName: "Sockets"
			vars:
				getSockets: () ->
					notiServer.getSockets()
		notifications:
			name: 'notifications'
			prettyName: 'Notifications'
		docs:
			name: 'docs'
			prettyName: "Documentation"
			path: "/docs/app.html"
			static: true

#### Route Manager
# Will create routes from a given `page` object.
	RouteManager =
		createRoute: (page) ->
			currentPath = page.path || "/#{page.name}"
			if not page.static
				notiServer[page.method || "get"](currentPath, (req, res) ->
					res.render(
						page.template || page.name
						pageTitle: page.prettyName || page.name
						siteTitle: SITE_TITLE
						navigation: Pages
						currentPath: currentPath,
						vars: page.vars || {}
					)
					return
				)
			return

##### Create all *Pages*
# Create the home page (root).
	RouteManager.createRoute(
		path: "/"
		name: "home"
		prettyName: "Home"
	)

# Iterate through all `Pages` and create a route for them
# using the `RouteManager`
	for currentPage of Pages
		RouteManager.createRoute(Pages[currentPage])
	
	
	
	return