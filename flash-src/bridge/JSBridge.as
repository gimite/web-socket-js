package bridge
{
	import flash.external.ExternalInterface;
	import flash.utils.setTimeout;

	/**
	 * This class provides a central location for ExternalInterface 
	 * communication between flash and javascript.
	 */
	public class JSBridge
	{
		private var controller : WebSocketMain;
		/**
		 * Class constructor.
		 */
		public function JSBridge(webSocketMainRef : WebSocketMain)
		{
			ExternalInterface.addCallback("setCallerUrl", onSetCallerUrl);
			ExternalInterface.addCallback("setDebug", onSetDebug);
			ExternalInterface.addCallback("createWebSocket", onCreateWebSocket);
			ExternalInterface.addCallback("send", onSend);
			ExternalInterface.addCallback("close", onClose);
			ExternalInterface.addCallback("loadFlashPolicyFile", onLoadFlashPolicyFile);
			
			controller = webSocketMainRef;
		}
		
		/******************
		 * Inbound calls from javascript
		 ******************/
		
		/**
		 * Set the url that this websocket is being opened from.
		 * @param callerUrl	The url that hosts the web socket request.
		 */
		public function onSetCallerUrl(callerUrl : String) : void {
			controller.setCallerUrl(callerUrl);
		}
		
		/**
		 * Set the debugging state.
		 * @param debug	True for debugging, false otherwise.
		 */
		public function onSetDebug(debug : Boolean) : void {
			controller.setDebug(debug);
		}
		
		/**
		 * Create a new websocket.
		 * @param webSocketId	Internal id for the new web socket.
		 * @param url			URL of the new socket.
		 * @param protocol		Protocol for the new socket.
		 * @param proxyHost		Host for the new socket.
		 * @param proxyPort		Port for the new socket.
		 * @param headers		Headers to include in socket communications.
		 */
		public function onCreateWebSocket(webSocketId : Number, url : String, protocol : String, proxyHost : String, proxyPort : Number, headers : String) : void {
			controller.create(webSocketId, url, protocol, proxyHost, proxyPort, headers);
		}
		
		/**
		 * Send the passed data to through the identified socket.
		 * @param webSocketId	Internal id for the target socket.
		 * @param data			The data to send through the socket.
		 */
		public function onSend(webSocketId : Number, data : String) : int {
			return controller.send(webSocketId, data);
		}
		
		/**
		 * Close the identified socket.
		 * @param webSocketId	Internal id for the target socket.
		 */
		public function onClose(webSocketId : Number) : void {
			controller.close(webSocketId);
		}
		
		/**
		 * Load a flash security policy file with the passed url.
		 * @param policyUrl	The url for the policy file to load.
		 */
		public function onLoadFlashPolicyFile(policyUrl : String) : void {
			setTimeout(controller.loadManualPolicyFile, 1, policyUrl);
		}
		
		/******************
		 * Outbound calls to javascript
		 ******************/
		/**
		 * Send a log message to javascript.
		 * @param message	The log message.
		 */
		public function log(message:String) : void {
			setTimeout(ExternalInterface.call, 1, "webSocketLog", encodeURIComponent("[WebSocket] " + message));
		}
		
		/**
		 * Send an error message to javascript.
		 * @param message	The error message.
		 */
		public function error(message:String) : void {
			setTimeout(ExternalInterface.call, 1, "webSocketError", encodeURIComponent("[WebSocket] " + message));
		}
		
		/**
		 * Alert javascript that flash has been initialized and is ready
		 * for communication.
		 */
		public function flashInitialized() : void {
			ExternalInterface.call("wsController.flashInitialized");
		}
		
		/**
		 * Send a WebSocket message to javascript.
		 * @param eventObj	A base Object containing the message addressing and contents:
		 * 					{webSocketId : event source socket,
		 * 					 type : event type ["open" | "close" | "error" | "message"],
		 * 					 readyState : current ready state of the source socket,
		 * 					 message : encoded message string
		 * @returns	True if javascript acknowledges receipt of the message, returns
		 * 			false if javascript is unresponsive.
		 */
		public function sendEvent(eventObj : Object) : Boolean {
			return ExternalInterface.call("wsController.flashEvent", eventObj) as Boolean;
		}
	}
}