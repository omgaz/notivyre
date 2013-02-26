var socket = null;
var Noti = {
	notificationHTML: "<tr><td class='message'><input type='checkbox' class='read'><span class='text'></span></td></tr>",
	setTabNotiCount: function(tab, count) {
		if(count <= 0) { jQuery("ul li[data-pagename=" + tab + "] div.noti").addClass('hide') }
		else { jQuery("ul li[data-pagename=" + tab + "] div.noti").removeClass('hide') }
		jQuery("ul li[data-pagename=" + tab + "] div.noti i").text(count).parent().fadeOut().fadeIn().fadeOut().fadeIn();
	},
	joinChannel: function(channel) {
		socket.emit("joinChannel", channel);
	},
	leaveChannel: function(channel) {
		socket.leave(channel);
	},
	submitSendChannelForm: function(e) {
		e.preventDefault();
		
		var channel = jQuery("#channels").val(),
			message = jQuery("#notiMsg").val();
		
		Noti.sendChannelMessage(channel, message);
	},
	sendChannelMessage: function(channel, message) {
		socket.emit('channelMsg', {
			channel: channel,
			message: message
		});
		this.queryForUnread();
	},
	displayNewMessage: function(notifications) {
		notifications = [].concat(notifications);
		
		for (var i=0; i < notifications.length; i++) {
			var notification = typeof notifications[i] === "object"? notifications[i] : JSON.parse(notifications[i]),
				thisMessage = jQuery(this.notificationHTML);
				
			thisMessage.attr("data-notificationId", notification.id);
			thisMessage.find("td.message span.text").html(notification.message);

			jQuery("table.messages tbody").append(thisMessage);
		};
	},
	addOption: function(username) {
		jQuery("#channels").append( jQuery("<option></option>").val(username).text(username) );
	},
	queryForUnread: function() {
		jQuery("table.messages tbody tr").remove();
		socket.emit('getAllReadNotifications', {userProfileId: jQuery("#channels").val()});
	},
	sendReadNotification: function (notificationIds) {
		socket.emit('readNotification', {
			userProfileId: jQuery("#channels").val(),
			notificationIds: notificationIds
		});
	},
	markAllAsRead: function(){
		var ids = [];
		jQuery("table.messages tr:has(input[type=checkbox]:not(:checked))").each(function(){
			ids.push( jQuery(this).data("notificationid") );
		});
		Noti.markNotificationsAsRead(ids);
	},
	markNotificationsAsRead: function (notifications) {
		notifications = [].concat(notifications);
		for (var i = notifications.length - 1; i >= 0; i--){
			var notification = notifications[i];
			jQuery("tr[data-notificationid=" + notification + "]").find("input[type=checkbox]").prop("disabled", true).next("span").attr("style", "text-decoration: line-through; color: #CACACA");
		};
		this.sendReadNotification(notifications);
	}
};

jQuery(document).ready(function(){
	socket = io.connect('http://gary.vyre.net');

	socket.on("updateSocketCount", function(data) {
		Noti.setTabNotiCount("sockets", data.count);
	});

	socket.on("notifications", function(notifications) {
		Noti.displayNewMessage(notifications);
	});
	
	jQuery("#sendMessage").click(Noti.submitSendChannelForm);
	jQuery("#notiMsg").parents("form:first").submit(Noti.submitSendChannelForm);
	jQuery("#queryForUnread").click(Noti.queryForUnread);
	jQuery("#selectUser").click(function() {
		jQuery("div.messageSection legend span").text(jQuery('#channels option:selected').text() + "'s Messages");
		jQuery("div.notifierSection, div.messageSection").show();
		Noti.queryForUnread();
		Noti.joinChannel(jQuery('#channels').val());
	});
	
	jQuery("table.messages").delegate("input[type=checkbox]", "change", function(e) {
		if(jQuery(this).is(':checked')){
			Noti.markNotificationsAsRead(jQuery(this).parents("tr:first").data("notificationid") );
		}
	});
	
	jQuery("#markAllAsRead").click(Noti.markAllAsRead);
});