## Sockets
# Everything to do with `WebSockets`. Including handling of redis events

# Cookie string to JSON conversion function.
parseCookie = require('connect').utils.parseCookie
url = require("url")

SESSION_DETECTION_TIMEOUT = 3000 # 3 seconds

#### Redis Keys
# These keys map to data within the system e.g. all unread notifications
class Keys
	constructor: (userProfileId) ->
		this.userProfileId = userProfileId
	allUnreadNotifications: () ->
		"notification:profileId:#{this.userProfileId}:unread"
	allReadNotifications: () ->
		"notification:profileId:#{this.userProfileId}:read"
	notificationChannel: () ->
		"notivyre:profileId:#{this.userProfileId}"
	profilePicture: () ->
		"profilePicture:profileId:#{this.userProfileId}"
	session: (domainName) ->
		"session:domainName:#{domainName}:siteId:1:profileId:#{this.userProfileId}"

#### Events Map
Events = 
	# `Events.Out`: `socket.emit` events, redis publish events etc...
	Out: 
		challenge: () ->
			"challenge"
		challengeResponse: () ->
			"challenge"
		notification : () ->
			"notification"
		notifications : () ->
			"notifications"	
		welcome: () ->
			"welcome"
		all: () ->
			"all"
		chatMessage: () ->
			"chat-message"
		allUnread: () ->
			"allUnread"
		allRead: () ->
			"allRead"
		markedAsRead: () ->
			"markedAsRead"
		presence: () ->
			"presence"
	# `Events.In`: `socket.on` events
	In:
		connection: () ->
			"connection"
		chatMessage: () ->
			"chat-message"
		challengeResponse: () ->
			"challengeResponse"
		subscribe: () ->
			"subscribe"
		message: () ->
			"message"
		disconnect: () ->
			"disconnect"
		markNotificationAsRead: () ->
			"readNotification"
		getAllNotifications: () ->
			"getAllNotifications"
		getAllUnreadNotifications: () ->
			"getAllUnreadNotifications"
		getAllReadNotifications: () ->
			"getAllReadNotifications"
			
			
		

module.exports = (notiServer, express, io, fn) ->
	sockets = []
	sessions = {}

	#### Announce Presence
	# Announces that a user, `profileId`, is coming online or going offline
	announcePresence = (profileId, isOnline) ->
		console.log("announcing presence #{profileId}")
		data =
			user:
				sessions[profileId]
			isOnline:
				isOnline

		for pid, session of sessions when (session.instanceID is sessions[profileId].instanceID) and (session.profileId isnt profileId)
			socks = getSocketsByProfileId(session.profileId)

			for socket in socks
				socket.json.emit(Events.Out.presence(), data)

	#### Emit Welcome
	# Sends a welcome message as well as all online users to the user logged in as `profileId`
	emitWelecome = (profileId) ->
		console.log("emitting welcome #{profileId}")
		user = sessions[profileId]

		data =
			message: "Welcome " + user.username
			onlineUsers: getOnlineUsers(user.instanceID)

		socks = getSocketsByProfileId(profileId)
		for socket in socks
			socket.json.emit(Events.Out.welcome(),data)


	#### Get Sockets
	getSockets = () ->
		sockets

	
	#### Get Socket By Profile Id
	getSocketsByProfileId = (userProfileId) ->
		userProfileId += ""

		result = []
		sockets.forEach((socket) ->
			if(socket.store.profileId == userProfileId)
				result.push(socket)
		)

		console.log("found #{result.length} sockets(s) for #{userProfileId}")
		return result

	#### Get online users
	# Returns an object of all online users
	getOnlineUsers = (instanceID) ->
		sess = {}
		for pid, session of sessions when session.instanceID is instanceID
			sess[pid] = session

		return sess

	#### Send Message
	sendMessage = (userTo, userFrom, text) ->
		console.log("sending #{text} to #{userTo}")
		socks = getSocketsByProfileId(userTo)
		data = 
			"userTo": userTo
			"userFrom": userFrom
			message: text

		for socket in socks
			socket.json.emit(Events.Out.chatMessage(), data)
		

	#### WebSocket Event Listeners
	# On socket connection, start listening for events from that socket.
	io.sockets.on(Events.In.connection(), (socket) ->

		redisKeys = null

		# Create `Redis` client and a `publisher` client for sending messages
		redisClient = notiServer.redis.createClient()
		redisSubscriber = notiServer.redis.createClient()

		hasSession = (challengeData, domainName, fn) ->

			#query redis
			console.log(redisKeys.session(domainName))
			redisClient.get(redisKeys.session(domainName), (err,data) ->
				
				if !err and data?
					sessions[challengeData.profileId] = challengeData

				fn(err,!err and data?)

			)
		
		# Ask who the user is
		socket.json.emit(Events.Out.challenge(),{})

		# On response of the challenge
		socket.on(Events.In.challengeResponse(), (challengeResponse) ->

			redisKeys = new Keys(challengeResponse.profileId)
			
			origin = socket.manager.handshaken[socket.store.id].headers.origin or socket.manager.handshaken[socket.store.id].headers.referer
			host = url.parse(origin).hostname
			existingSession = sessions[challengeResponse.profileId]

			hasSession(challengeResponse, host, (err, result) ->
				if err? or !result
					data =
						error:
							err
						message:
							"auth failed"
					socket.json.emit("error", data)
					socket.disconnect()
				else
					socket.store.profileId = challengeResponse.profileId
					redisClient.get(redisKeys.profilePicture(), (err, url, event) ->
						if !err and url?
							sessions[challengeResponse.profileId].profilePictureUrl = url

						emitWelecome(challengeResponse.profileId);

						if !existingSession
							announcePresence(challengeResponse.profileId,true)
							redisSubscriber.subscribe(redisKeys.notificationChannel())
					)
			)		
				
		)
		
		# On chat message received from client, `data.userFrom`, send out to the designated user, `data.userTo`
		socket.on(Events.In.chatMessage(), (data) ->
			console.log("received chat message", data)
			sendMessage(data.userTo, data.userFrom, data.message)
		)
		
		# On Redis subscription event being fired
		redisSubscriber.on(Events.In.subscribe(), (channel, count) ->
			# On Redis publishing a message
			redisSubscriber.on(Events.In.message(), (channel, notification) ->
				jNotification = JSON.parse(notification)
				
				console.log " > New '#{jNotification.type}' message for #{channel} "
				console.log("notification was #{notification}")
				socks = getSocketsByProfileId(jNotification.destinationUserProfileId)
				for sock in socks
					sock.json.emit(Events.Out.notification(), jNotification)
			)
			console.log("<  Client subscribed to '#{channel}', '#{count}' total subscriptions.")
		)
		

		# Increment socket count
		sockets.push(socket)
		
		sendNotificationsToClient = (err, notifications, event) ->

			jsonArray = []
			for key, noti of notifications
				jsonArray.push(JSON.parse(noti))

			if err then	console.log(">>> ERR:", err)
			else
				# TODO: Update to getCurrentUser().username, but currently breaks when using the monitor
				console.log " > Sending #{jsonArray.length} notifications to #{socket.store.profileId} to '#{event}'."
				socket.json.emit(event || Events.Out.notifications(), jsonArray)
			return
		
		# Get all `read` notifications
		getAllRead = (redisKeys) ->
			redisClient.hgetall(redisKeys.allReadNotifications(), (err, notifications) ->
				sendNotificationsToClient(err, notifications, Events.Out.allRead())
			)

		# Get all `unread` notifications
		getAllUnread = (redisKeys) ->
			redisClient.hgetall(redisKeys.allUnreadNotifications(), (err, notifications) ->
				sendNotificationsToClient(err, notifications, Events.Out.allUnread())
			)

		getCurrentUser = () ->
			sessions[socket.store.profileId]


		##### On Disconnect
		# Decrease socket count and broadcast the event
		socket.on(Events.In.disconnect(), () ->

			console.log("xxx #{socket.store.profileId} disconnected xxx");

			redisKeys = new Keys(socket.store.profileId)
			sockets.splice(sockets.indexOf(socket),1)

			origin = socket.manager.handshaken[socket.store.id].headers.origin or socket.manager.handshaken[socket.store.id].headers.referer
			host = url.parse(origin).hostname

			# This is purposfully blocking
			setTimeout(() ->
				redisClient.get(redisKeys.session(host), (err, resp) ->
					console.log("detecting logout #{err} #{resp == true}")
					if !err and resp == null
						announcePresence(socket.store.profileId,false)
						delete sessions[socket.store.profileId]
						redisClient.quit()
						redisSubscriber.quit()
				)
			, SESSION_DETECTION_TIMEOUT);
			return
		)
		
		
		##### On Notification Read
		# Allows to send one or many (array) notifications into the 'read' state.
		socket.on(Events.In.markNotificationAsRead(), (data) ->
			
			# Cast notifications to an array if not already
			notifications = [].concat(data.notificationIds)
			getCommands = []

			userProfileId = socket.store.profileId || data.userProfileId
			redisKeys = if !redisKeys then new Keys(userProfileId) else redisKeys

			# Timestamp the read notification using ISO String format e.g. `2012-03-19T16:48:08.121Z`
			nowIso = new Date().toISOString()

			# Construct an array of all the things we want Redis to do
			for notification in notifications
				
				getCommands.push( ["hget", redisKeys.allUnreadNotifications(), notification] )

			# Send off all the commands as one request
			redisClient.multi(getCommands).exec( (err, notifications) ->
				updateCommands = []
				readNotifications = []

				for notification in notifications
					if(notification)
						notification = JSON.parse(notification)
					
						notification.readDate = nowIso
					
						# Save the `read` notification ids to send to client
						readNotifications.push(notification.id)
				
						# Delete the field from the unread key...
						updateCommands.push(["hdel", redisKeys.allUnreadNotifications(), notification.id
						])
						# ... and add it to the `read` key, when deleted, with updated 'readDate' timestamp (set above)
						updateCommands.push(["hset", redisKeys.allReadNotifications(), notification.id, JSON.stringify(notification)
						])
				
				# Run update commands (delete and set)
				redisClient.multi(updateCommands).exec( (err, replies) ->
					socket.json.emit(Events.Out.markedAsRead(), readNotifications)
					console.log " > Successfully marked #{replies.length / 2} notifications as read."
				)

			)

			return
		)
		
		#### Get Notification Events
		##### On Get All Notifications
		socket.on(Events.In.getAllNotifications(), (data) ->
			redisKeys = if !redisKeys then new Keys(data.userProfileId) else redisKeys
			
			# Get all `unread` notifications
			getAllUnread(redisKeys)
			# Get all `read` notifications
			getAllRead(redisKeys)
		)
		
		##### On Get All Read Notifications
		socket.on(Events.In.getAllReadNotifications(), (data) ->
			redisKeys = if !redisKeys then new Keys(data.userProfileId) else redisKeys

			# Get all `read` notifications
			getAllRead(redisKeys)
		)
		
		##### On Get All Un-Read Notifications
		socket.on(Events.In.getAllUnreadNotifications(), (data) ->
			redisKeys = if !redisKeys then new Keys(data.userProfileId) else redisKeys

			# Get all `unread` notifications
			getAllUnread(redisKeys)
		)



		##### Test Code
		# Used for sending dummy data and dummy subscriptions
		socket.on("joinChannel", (channel) ->
			console.log("<  Joining channel #{channel}")
			redisSubscriber.subscribe channel
		)
		
		
		socket.on('channelMsg', (data) ->
			
			redisKeys = new Keys(data.channel)
			now = new Date()
			timestamp = now.getTime()
			
			# An example JSON package of notification data
			jsonPackage =
				# Unique notification identifier
				"id": timestamp
				# The time now in ISO string format
				"creationDate": now.toISOString()
				# Using data.channel for now in the testing. This needs to be the userProfileId
				"originUserId": 96
				# Just notify the current user with everything so far
				"destinationUserId": 96
				# The pre-formatted message HTML
				"message": data.message
				# When the notification has been read by a use then store a 'read' timestamp, if unread don't store a value
				# readDate: timestamp
				# This will be a camelCased type e.g. creativeUploaded or PORejected
				"notificationType": data.message
				# The icon for the particular action
				"icon": data.icon || "stage"
				"originUserProfileId": data.channel
				"originUserFullName": "NotiVYRE Monitor"
				"destinationUserProfileId": data.channel
				"destinationUserFullName": "NotiVYRE Monitor"
				

			console.log " > Emitting New Notification (#{jsonPackage.notificationType})"

		
			redisClient.publish(redisKeys.notificationChannel(),JSON.stringify(jsonPackage))
			redisClient.hset(redisKeys.allUnreadNotifications(), timestamp, JSON.stringify(jsonPackage), (err, reply) ->
				if err?
					console.log "       ~ error:", err
				else console.log "       ~ done."
			)
		)
		
		
	)

	fn(getSockets)
	return


