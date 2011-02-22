// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol

(function() {
  
	if (window.WebSocket) return;
	
	var console = window.console;
	if (!console || !console.log || !console.error) {
		console = {log: function(){ }, error: function(){ }};
	}
	
	if (!swfobject.hasFlashPlayerVersion("9.0.0")) {
		console.error("Flash Player is not installed.");
		return;
	}
	if (location.protocol == "file:") {
		console.error(
			"WARNING: web-socket-js doesn't work in file:///... URL " +
			"unless you set Flash Security Settings properly. " +
			"Open the page via Web server i.e. http://...");
	}
  
	WebSocketController = function() {
		this._webSockets = {};
		this._initializing = false;
		this._initialized = false;
		this._currentWebSocketId = 0;
		this._flashObj = null;
	};
	
	/**
	 * Load and initialize the flash
	 * mock web socket.
	 */
	WebSocketController.prototype.init = function() {
		if (this._initialized || this._initializing) {
			return;
		}
		this._initializing = true;
		
		if (WebSocket.__swfLocation) {
			// For backword compatibility.
			window.WEB_SOCKET_SWF_LOCATION = WebSocket.__swfLocation;
		}
		if (!window.WEB_SOCKET_SWF_LOCATION) {
			console.error("[WebSocket] set WEB_SOCKET_SWF_LOCATION to location of WebSocketMain.swf");
			return;
		}
		var container = document.createElement("div");
		container.id = "webSocketContainer";
		// Hides Flash box. We cannot use display: none or visibility: hidden because it prevents
		// Flash from loading at least in IE. So we move it out of the screen at (-100, -100).
		// But this even doesn't work with Flash Lite (e.g. in Droid Incredible). So with Flash
		// Lite, we put it at (0, 0). This shows 1x1 box visible at left-top corner but this is
		// the best we can do as far as we know now.
		container.style.position = "absolute";
		if (this.__isFlashLite()) {
			container.style.left = "0px";
			container.style.top = "0px";
		} else {
			container.style.left = "-100px";
			container.style.top = "-100px";
		}
		var holder = document.createElement("div");
		holder.id = "webSocketFlash";
		container.appendChild(holder);
		document.body.appendChild(container);
		// See this article for hasPriority:
		// http://help.adobe.com/en_US/as3/mobile/WS4bebcd66a74275c36cfb8137124318eebc6-7ffd.html
		swfobject.embedSWF(
			WEB_SOCKET_SWF_LOCATION, 
			"webSocketFlash",
			"1" /* width */, 
			"1" /* height */, 
			"10.0.0" /* SWF version */,
			null, 
			null, 
			{hasPriority: true, swliveconnect : true, allowScriptAccess: "always"}, 
			null,
			function(e) {
				if (!e.success) {
					console.error("[WebSocket] swfobject.embedSWF failed");
				}
			});
	};
	
	/**
	 * Called by flash to notify js that it's fully loaded and ready
	 * for communication.
	 */
	WebSocketController.prototype.flashInitialized = function() {
		//We need to set a timeout here to avoid round-trip calls
		//to flash during the initialization process.
		setTimeout(function() {
			wsController._onFlashInitialized();
		}, 0);
	};
		
	/**
	 * Method called once flash is ready for communication.
	 */
	WebSocketController.prototype._onFlashInitialized = function() {
		var webSocket;
		
		this._initialized = true;
		this._flashObj = document.getElementById('webSocketFlash');
		this._flashObj.setCallerUrl(location.href);
		this._flashObj.setDebug(!!window.WEB_SOCKET_DEBUG);
		
		//If we have any policy files waiting to be loaded, load them.
		if (this._policyUrls) {
			var i = this._policyUrls.length;
			while (i-->0) {
				this._flashObj.loadFlashPolicyFile(this._policyUrls[i]);
			}
		}
		
		//If we have any websockets ready to go, initialize them.
		for (var webSocketId in this._webSockets) {
			webSocket = this._webSockets[webSocketId];
			this._flashObj.createWebSocket(webSocketId, webSocket.url, webSocket.protocol, webSocket.proxyHost, webSocket.proxyPort, webSocket.headers);
		}
	};
		
	/**
	 * Create a new websocket instance in flash and send the new web socket id back
	 * to the caller.
	 * @param {WebSocket} webSocket	The websocket instance handling this web socket.
	 * @return {int}	The new flash web socket id.
	 */
	WebSocketController.prototype.createFlashWebSocket = function(webSocket) {
		var webSocketId = this._currentWebSocketId++;
		
		this._webSockets[webSocketId] = webSocket;
		
		//If the flash component has been initialized, open the web socket connection
		if (this._initialized) {
			this._flashObj.createWebSocket(webSocketId, webSocket.url, webSocket.protocol, webSocket.proxyHost, webSocket.proxyPort, webSocket.headers);
		} else if (!this._initializing) {
			//Load flash swf and initialize
			this.init();
		}
		
		return webSocketId;
	};
	
	/**
	 * Send data through the flash socket.
	 * @param {int} socketId	ID of the web socket to use.
	 * @param {string} data		Data to send.
	 */
	WebSocketController.prototype.send = function(socketId, data) {
		return this._flashObj.send(socketId, data);
	};
	
	
	/**
	 * Close the flash socket.
	 * @param {int} socketId	ID of the web socket to use.
	 */
	WebSocketController.prototype.close = function(socketId) {
		return this._flashObj.close(socketId);
	};
	
	/**
	 * Test if the browser is running flash lite.
	 * @return {boolean} True if flash lite is running, false otherwise.
	 */
	WebSocketController.prototype.__isFlashLite = function() {
		if (!window.navigator || !window.navigator.mimeTypes) {
			return false;
		}
		var mimeType = window.navigator.mimeTypes['application/x-shockwave-flash'];
		if (!mimeType || !mimeType.enabledPlugin || !mimeType.enabledPlugin.filename) {
			return false;
		}
		return mimeType.enabledPlugin.filename.match(/flashlite/i) ? true : false;
	};
	
	/**
	 * Called by flash to dispatch an event to a web socket.
	 * @param {object} eventObj	A web socket event dispatched from flash.
	 */
	WebSocketController.prototype.flashEvent = function(eventObj) {
		var socketId = eventObj.webSocketId,
			wsEvent = new WebSocketEvent();
		
		wsEvent.initEvent(eventObj.type, true, true);
		wsEvent.readyState = eventObj.readyState;
		wsEvent.message = eventObj.message;
		
		setTimeout(function() {
			wsController.dispatchEvent(socketId, wsEvent);
		}, 0);
		
		return true;
	};
	
	WebSocketController.prototype.dispatchEvent = function(webSocketId, wsEvent) {
		this._webSockets[webSocketId].__handleEvent(wsEvent);
	};
	
	/**
	 * Load a new flash security policy file.
	 * @param {string} url
	 */
	WebSocketController.prototype.loadFlashPolicyFile = function(url){
		if (this._initialized) {
			this._flashObj.loadFlashPolicyFile(url);
		}
		else {
			this._policyUrls = this._policyUrls || [];
			this._policyUrls.push(url);
		}
	};





	/**
	 * This class represents a faux web socket.
	 * @param {string} url
	 * @param {string} protocol
	 * @param {string} proxyHost
	 * @param {int} proxyPort
	 * @param {string} headers
	 */
	WebSocket = function(url, protocol, proxyHost, proxyPort, headers) {
		this.url = url;
		this.protocol = protocol;
		this.proxyHost = proxyHost;
		this.headers = headers;
		
		this.readyState = WebSocket.CONNECTING;
		this.bufferedAmount = 0;
		this._socketId = wsController.createFlashWebSocket(this);
	};

	/**
	 * Send data to the web socket.
	 * @param {string} data	The data to send to the socket.
	 * @return {boolean}	True for success, false for failure.
	 */
	WebSocket.prototype.send = function(data) {
		if (this.readyState == WebSocket.CONNECTING) {
			throw "INVALID_STATE_ERR: Web Socket connection has not been established";
		}
		// We use encodeURIComponent() here, because FABridge doesn't work if
		// the argument includes some characters. We don't use escape() here
		// because of this:
		// https://developer.mozilla.org/en/Core_JavaScript_1.5_Guide/Functions#escape_and_unescape_Functions
		// But it looks decodeURIComponent(encodeURIComponent(s)) doesn't
		// preserve all Unicode characters either e.g. "\uffff" in Firefox.
		// Note by wtritch: Hopefully this will not be necessary using ExternalInterface.  Will require
		// additional testing.
		var result = wsController.send(this._socketId, encodeURIComponent(data));
		if (result < 0) { // success
			return true;
		} else {
			this.bufferedAmount += result;
			return false;
		}
	};

	/**
	 * Close this web socket gracefully.
	 */
	WebSocket.prototype.close = function() {
		if (this.readyState == WebSocket.CLOSED || this.readyState == WebSocket.CLOSING) {
			return;
		}
		this.readyState = WebSocket.CLOSING;
		wsController.close(this._socketId);
	};

	/**
	 * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
	 *
	 * @param {string} type
	 * @param {function} listener
	 * @param {boolean} useCapture !NB Not implemented yet
	 * @return void
	 */
	WebSocket.prototype.addEventListener = function(type, listener, useCapture) {
		if (!('__events' in this)) {
			this.__events = {};
		}
		if (!(type in this.__events)) {
			this.__events[type] = [];
			if ('function' == typeof this['on' + type]) {
				this.__events[type].defaultHandler = this['on' + type];
				this['on' + type] = this.__createEventHandler(this, type);
			}
		}
		this.__events[type].push(listener);
	};

	/**
	 * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
	 *
	 * @param {string} type
	 * @param {function} listener
	 * @param {boolean} useCapture NB! Not implemented yet
	 * @return void
	 */
	WebSocket.prototype.removeEventListener = function(type, listener, useCapture) {
		if (!('__events' in this)) {
			this.__events = {};
		}
		if (!(type in this.__events)) return;
		for (var i = this.__events.length; i > -1; --i) {
			if (listener === this.__events[type][i]) {
				this.__events[type].splice(i, 1);
				break;
			}
		}
	};

	/**
	 * Implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-registration">DOM 2 EventTarget Interface</a>}
	 *
	 * @param {WebSocketEvent} event
	 * @return void
	 */
	WebSocket.prototype.dispatchEvent = function(event) {
		if (!('__events' in this)) throw 'UNSPECIFIED_EVENT_TYPE_ERR';
		if (!(event.type in this.__events)) throw 'UNSPECIFIED_EVENT_TYPE_ERR';
	
		for (var i = 0, l = this.__events[event.type].length; i < l; ++ i) {
			this.__events[event.type][i](event);
			if (event.cancelBubble) break;
		}
	
		if (false !== event.returnValue &&
			'function' == typeof this.__events[event.type].defaultHandler)
		{
			this.__events[event.type].defaultHandler(event);
		}
	};

	/**
	 * Handle an event from flash.  Do any websocket-specific
	 * handling before passing the event off to the event handlers.
	 * @param {Object} event
	 */
	WebSocket.prototype.__handleEvent = function(event) {
		// Gets events using receiveEvents() instead of getting it from event object
		// of Flash event. This is to make sure to keep message order.
		// It seems sometimes Flash events don't arrive in the same order as they are sent.
		if (event.readyState >= 0) {
			this.readyState = event.readyState;
		}
		
		try {
			if (event.type == "open" && this.onopen) {
				this.onopen();
			} else if (event.type == "close" && this.onclose) {
				this.onclose();
			} else if (event.type == "error" && this.onerror) {
				this.onerror(event);
			} else if (event.type == "message") {
				if (this.onmessage) {
					var data = decodeURIComponent(event.message);
					var e;
					if (window.MessageEvent && !window.opera) {
						e = document.createEvent("MessageEvent");
						e.initMessageEvent("message", false, false, data, null, null, window, null);
					} else {
						// IE and Opera, the latter one truncates the data parameter after any 0x00 bytes.
						e = {data: data};
					}
					this.onmessage(e);
				}
				
			}  else {
				throw "unknown event type: " + event.type;
			}
		} catch (e) {
			console.error(e.toString());
		}
	};
  
	/**
	 * @param {object} object
	 * @param {string} type
	 */
	WebSocket.prototype.__createEventHandler = function(object, type) {
		return function(data) {
			var event = new WebSocketEvent();
			event.initEvent(type, true, true);
			event.target = event.currentTarget = object;
			for (var key in data) {
				event[key] = data[key];
			}
			object.dispatchEvent(event, arguments);
		};
	};

	/**
	 * Load the specified flash security policy file.
	 * NOTE: This should be called prior to instantiating any WebSockets.
	 * @param {string} url	URL to the remote policy file.
	 */
	WebSocket.loadFlashPolicyFile = function(url) {
		wsController.loadFlashPolicyFile(url);
	};

	/**
	 * Define the WebSocket readyState enumeration.
	 */
	WebSocket.CONNECTING = 0;
	WebSocket.OPEN = 1;
	WebSocket.CLOSING = 2;
	WebSocket.CLOSED = 3;

	/**
	 * Basic implementation of {@link <a href="http://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-interface">DOM 2 EventInterface</a>}
	 *
	 * @class
	 * @constructor
	 */
	function WebSocketEvent(){}
	
	/**
	 * @type int	WebSocket state enumeration
	 */
	WebSocketEvent.prototype.readyState = -1;
	
	/**
	 * @type string	message received from the flash socket.
	 */
	WebSocketEvent.prototype.message = null;
	
	/**
	 *
	 * @type boolean
	 */
	WebSocketEvent.prototype.cancelable = true;
	
	/**
	*
	* @type boolean
	*/
	WebSocketEvent.prototype.cancelBubble = false;
	
	/**
	*
	* @return void
	*/
	WebSocketEvent.prototype.preventDefault = function() {
		if (this.cancelable) {
			this.returnValue = false;
		}
	};
	
	/**
	*
	* @return void
	*/
	WebSocketEvent.prototype.stopPropagation = function() {
		this.cancelBubble = true;
	};

	/**
	*
	* @param {string} eventTypeArg
	* @param {boolean} canBubbleArg
	* @param {boolean} cancelableArg
	* @return void
	*/
	WebSocketEvent.prototype.initEvent = function(eventTypeArg, canBubbleArg, cancelableArg) {
		this.type = eventTypeArg;
		this.cancelable = cancelableArg;
		this.timeStamp = new Date();
	};


	window.wsController = new WebSocketController();

	// called from Flash
	window.webSocketLog = function(message) {
		console.log(decodeURIComponent(message));
	};
	
	// called from Flash
	window.webSocketError = function(message) {
		console.error(decodeURIComponent(message));
	};
	
	if (!window.WEB_SOCKET_DISABLE_AUTO_INITIALIZATION) {
		if (window.addEventListener) {
			window.addEventListener("load", function(){
				wsController.init();
			}, false);
		} else {
			window.attachEvent("onload", function(){
				wsController.init();
			});
		}
	}
  
})();
