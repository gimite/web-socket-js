// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76

package {
	
	import bridge.JSBridge;
	
	import flash.display.Sprite;
	import flash.system.Security;
	import flash.utils.setTimeout;
	
	import mx.utils.URLUtil;
	
	public class WebSocketMain extends Sprite {
		
		private var callerUrl:String;
		private var debug:Boolean = false;
		private var manualPolicyFileLoaded:Boolean = false;
		private var jsBridge : JSBridge;
		private var webSockets : Array;
		private var eventQueue : Array;
		
		public function WebSocketMain() {
			this.jsBridge = new JSBridge(this);
			webSockets = new Array();
			eventQueue = new Array();
			jsBridge.flashInitialized();
		}
		
		/*************
		 * Initialization / Utility methods
		 */
		
		public function setCallerUrl(url:String):void {
			callerUrl = url;
		}
		
		public function setDebug(val:Boolean):void {
			debug = val;
		}
		
		public function getOrigin():String {
			return (URLUtil.getProtocol(this.callerUrl) + "://" +
				URLUtil.getServerNameWithPort(this.callerUrl)).toLowerCase();
		}
		
		public function getCallerHost():String {
			return URLUtil.getServerName(this.callerUrl);
		}
		
		private function loadDefaultPolicyFile(wsUrl:String):void {
			var policyUrl:String = "xmlsocket://" + URLUtil.getServerName(wsUrl) + ":843";
			log("policy file: " + policyUrl);
			Security.loadPolicyFile(policyUrl);
		}
		
		public function loadManualPolicyFile(policyUrl:String):void {
			log("policy file: " + policyUrl);
			Security.loadPolicyFile(policyUrl);
			manualPolicyFileLoaded = true;
		}
		
		public function log(message:String):void {
			if (debug) {
				jsBridge.log(message);
			}
		}
		
		public function error(message:String):void {
			jsBridge.error(message);
		}
		
		public function fatal(message:String):void {
			jsBridge.error(message);
		}
		
		private function parseEvent(event : WebSocketEvent) : Object {
			var eventObj : Object = new Object();
			var webSocket : WebSocket = event.target as WebSocket;
			eventObj.type = event.type;
			eventObj.webSocketId = webSocket.webSocketId;
			eventObj.readyState = webSocket.readOnly_readyState;
			if (event.message !== null) {
				eventObj.message = event.message;
			}
			return eventObj;
		}
		
		/**
		 * Socket interface
		 */
		public function create(
			webSocketId : Number,
			url:String, protocol:String,
			proxyHost:String = null, proxyPort:int = 0,
			headers:String = null):void {
			if (!manualPolicyFileLoaded) {
				loadDefaultPolicyFile(url);
			}
			var newSocket : WebSocket = new WebSocket(this, webSocketId, url, protocol, proxyHost, proxyPort, headers);
			newSocket.addEventListener(WebSocketEvent.OPEN, onSocketEvent);
			newSocket.addEventListener(WebSocketEvent.CLOSE, onSocketEvent);
			newSocket.addEventListener(WebSocketEvent.ERROR, onSocketEvent);
			newSocket.addEventListener(WebSocketEvent.MESSAGE, onSocketEvent);
			webSockets[webSocketId] = newSocket;
		}
		
		public function send(webSocketId : Number, encData : String) : int {
			var webSocket : WebSocket = webSockets[webSocketId];
			return webSocket.send(encData);
		}
		
		public function close(webSocketId : Number) : void {
			var webSocket : WebSocket = webSockets[webSocketId];
			webSocket.close();
		}
		
		
		/****************
		 * Socket event handler
		 */
		public function onSocketEvent(event : WebSocketEvent) : void {
			var eventObj : Object = parseEvent(event);
			eventQueue.push(eventObj);
			setTimeout(processEvents, 1);
		}
		
		/**
		 * Process our event queue.  If javascript is unresponsive, set
		 * a timeout and try again.
		 */
		public function processEvents() : void {
			var eventObj : Object;
			var success : Boolean;
			while (eventQueue.length > 0) {
				eventObj = eventQueue[0];
				success = jsBridge.sendEvent(eventObj);
				if (!success) {
					setTimeout(processEvents, 500);
					break;
				} else {
					eventQueue.shift();
				}
			}
		}
		
	}
	
}
