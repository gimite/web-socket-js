// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/rfc6455

package net.gimite.websocket {

import com.adobe.net.proxies.RFC2817Socket;
import com.gsolo.encryption.SHA1;
import com.hurlant.crypto.tls.TLSConfig;
import com.hurlant.crypto.tls.TLSEngine;
import com.hurlant.crypto.tls.TLSSecurityParameters;
import com.hurlant.crypto.tls.TLSSocket;

import flash.display.*;
import flash.errors.*;
import flash.events.*;
import flash.external.*;
import flash.net.*;
import flash.system.*;
import flash.utils.*;

import mx.controls.*;
import mx.core.*;
import mx.events.*;
import mx.utils.*;

public class WebSocket extends EventDispatcher {
  
  private static const WEB_SOCKET_GUID:String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
  
  private static const CONNECTING:int = 0;
  private static const OPEN:int = 1;
  private static const CLOSING:int = 2;
  private static const CLOSED:int = 3;
  
  private static const OPCODE_CONTINUATION:int = 0x00;
  private static const OPCODE_TEXT:int = 0x01;
  private static const OPCODE_BINARY:int = 0x02;
  private static const OPCODE_CLOSE:int = 0x08;
  private static const OPCODE_PING:int = 0x09;
  private static const OPCODE_PONG:int = 0x0a;
  
  private static const STATUS_NORMAL_CLOSURE:int = 1000;
  private static const STATUS_NO_CODE:int = 1005;
  private static const STATUS_CLOSED_ABNORMALLY:int = 1006;
  private static const STATUS_CONNECTION_ERROR:int = 5000;
  
  private var id:int;
  private var url:String;
  private var scheme:String;
  private var host:String;
  private var port:uint;
  private var path:String;
  private var origin:String;
  private var requestedProtocols:Array;
  private var cookie:String;
  private var headers:String;
  
  private var rawSocket:Socket;
  private var tlsSocket:TLSSocket;
  private var tlsConfig:TLSConfig;
  private var socket:Socket;
  
  private var acceptedProtocol:String;
  private var expectedDigest:String;
  
  private var buffer:ByteArray = new ByteArray();
  private var fragmentsBuffer:ByteArray = null;
  private var headerState:int = 0;
  private var readyState:int = CONNECTING;
  
  private var logger:IWebSocketLogger;
  private var base64Encoder:Base64Encoder = new Base64Encoder();
  
  public function WebSocket(
      id:int, url:String, protocols:Array, origin:String,
      proxyHost:String, proxyPort:int,
      cookie:String, headers:String,
      logger:IWebSocketLogger) {
    this.logger = logger;
    this.id = id;
    this.url = url;
    var m:Array = url.match(/^(\w+):\/\/([^\/:]+)(:(\d+))?(\/.*)?(\?.*)?$/);
    if (!m) fatal("SYNTAX_ERR: invalid url: " + url);
    this.scheme = m[1];
    this.host = m[2];
    var defaultPort:int = scheme == "wss" ? 443 : 80;
    this.port = parseInt(m[4]) || defaultPort;
    this.path = (m[5] || "/") + (m[6] || "");
    this.origin = origin;
    this.requestedProtocols = protocols;
    this.cookie = cookie;
    // if present and not the empty string, headers MUST end with \r\n
    // headers should be zero or more complete lines, for example
    // "Header1: xxx\r\nHeader2: yyyy\r\n"
    this.headers = headers;
    
    if (proxyHost != null && proxyPort != 0){
      if (scheme == "wss") {
        fatal("wss with proxy is not supported");
      }
      var proxySocket:RFC2817Socket = new RFC2817Socket();
      proxySocket.setProxyInfo(proxyHost, proxyPort);
      proxySocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
      rawSocket = socket = proxySocket;
    } else {
      rawSocket = new Socket();
      if (scheme == "wss") {
        tlsConfig= new TLSConfig(TLSEngine.CLIENT,
            null, null, null, null, null,
            TLSSecurityParameters.PROTOCOL_VERSION);
        tlsConfig.trustAllCertificates = true;
        tlsConfig.ignoreCommonNameMismatch = true;
        tlsSocket = new TLSSocket();
        tlsSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
        socket = tlsSocket;
      } else {
        rawSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
        socket = rawSocket;
      }
    }
    rawSocket.addEventListener(Event.CLOSE, onSocketClose);
    rawSocket.addEventListener(Event.CONNECT, onSocketConnect);
    rawSocket.addEventListener(IOErrorEvent.IO_ERROR, onSocketIoError);
    rawSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketSecurityError);
    rawSocket.connect(host, port);
  }
  
  /**
   * @return  This WebSocket's ID.
   */
  public function getId():int {
    return this.id;
  }
  
  /**
   * @return this WebSocket's readyState.
   */
  public function getReadyState():int {
    return this.readyState;
  }

  public function getAcceptedProtocol():String {
    return this.acceptedProtocol;
  }
  
  public function send(encData:String):int {
    var data:String;
    try {
      data = decodeURIComponent(encData);
    } catch (ex:URIError) {
      logger.error("SYNTAX_ERR: URIError in send()");
      return 0;
    }
    logger.log("send: " + data);
    var dataBytes:ByteArray = new ByteArray();
    dataBytes.writeUTFBytes(data);
    if (readyState == OPEN) {
      var frame:WebSocketFrame = new WebSocketFrame();
      frame.opcode = OPCODE_TEXT;
      frame.payload = dataBytes;
      if (sendFrame(frame)) {
        return -1;
      } else {
        return dataBytes.length;
      }
    } else if (readyState == CLOSING || readyState == CLOSED) {
      return dataBytes.length;
    } else {
      fatal("invalid state");
      return 0;
    }
  }
  
  public function close(
      code:int = STATUS_NO_CODE, reason:String = "", origin:String = "client"):void {
    if (code != STATUS_NORMAL_CLOSURE &&
        code != STATUS_NO_CODE &&
        code != STATUS_CONNECTION_ERROR) {
      logger.error(StringUtil.substitute(
          "Fail connection by {0}: code={1} reason={2}", origin, code, reason));
    }
    var closeConnection:Boolean =
        code == STATUS_CONNECTION_ERROR || origin == "server";
    try {
      if (readyState == OPEN && code != STATUS_CONNECTION_ERROR) {
        var frame:WebSocketFrame = new WebSocketFrame();
        frame.opcode = OPCODE_CLOSE;
        frame.payload = new ByteArray();
        if (origin == "client" && code != STATUS_NO_CODE) {
          frame.payload.writeShort(code);
          frame.payload.writeUTFBytes(reason);
        }
        sendFrame(frame);
      }
      if (closeConnection) {
        socket.close();
      }
    } catch (ex:Error) {
      logger.error("Error: " + ex.message);
    }
    if (closeConnection) {
      logger.log("closed");
      var fireErrorEvent:Boolean = readyState != CONNECTING && code == STATUS_CONNECTION_ERROR;
      readyState = CLOSED;
      if (fireErrorEvent) {
        dispatchEvent(new WebSocketEvent("error"));
      }
      var wasClean:Boolean = code != STATUS_CLOSED_ABNORMALLY && code != STATUS_CONNECTION_ERROR;
      var eventCode:int = code == STATUS_CONNECTION_ERROR ? STATUS_CLOSED_ABNORMALLY : code;
      dispatchCloseEvent(wasClean, eventCode, reason);
    } else {
      logger.log("closing");
      readyState = CLOSING;
    }
  }
  
  private function onSocketConnect(event:Event):void {
    logger.log("connected");

    if (scheme == "wss") {
      logger.log("starting SSL/TLS");
      tlsSocket.startTLS(rawSocket, host, tlsConfig);
    }
    
    var defaultPort:int = scheme == "wss" ? 443 : 80;
    var hostValue:String = host + (port == defaultPort ? "" : ":" + port);
    var key:String = generateKey();

    SHA1.b64pad = "=";
    expectedDigest = SHA1.b64_sha1(key + WEB_SOCKET_GUID);

    var opt:String = "";
    if (requestedProtocols.length > 0) {
      opt += "Sec-WebSocket-Protocol: " + requestedProtocols.join(",") + "\r\n";
    }
    // if caller passes additional headers they must end with "\r\n"
    if (headers) opt += headers;
    
    var req:String = StringUtil.substitute(
      "GET {0} HTTP/1.1\r\n" +
      "Host: {1}\r\n" +
      "Upgrade: websocket\r\n" +
      "Connection: Upgrade\r\n" +
      "Sec-WebSocket-Key: {2}\r\n" +
      "Origin: {3}\r\n" +
      "Sec-WebSocket-Version: 13\r\n" +
      (cookie == "" ? "" : "Cookie: {4}\r\n") +
      "{5}" +
      "\r\n",
      path, hostValue, key, origin, cookie, opt);
    logger.log("request header:\n" + req);
    socket.writeUTFBytes(req);
    socket.flush();
  }

  private function onSocketClose(event:Event):void {
    logger.log("closed");
    readyState = CLOSED;
    dispatchCloseEvent(false, STATUS_CLOSED_ABNORMALLY, "");
  }

  private function onSocketIoError(event:IOErrorEvent):void {
    var message:String;
    if (readyState == CONNECTING) {
      message = "cannot connect to Web Socket server at " + url + " (IoError: " + event.text + ")";
    } else {
      message =
          "error communicating with Web Socket server at " + url +
          " (IoError: " + event.text + ")";
    }
    onConnectionError(message);
  }

  private function onSocketSecurityError(event:SecurityErrorEvent):void {
    var message:String;
    if (readyState == CONNECTING) {
      message =
          "cannot connect to Web Socket server at " + url + " (SecurityError: " + event.text + ")\n" +
          "make sure the server is running and Flash socket policy file is correctly placed";
    } else {
      message =
          "error communicating with Web Socket server at " + url +
          " (SecurityError: " + event.text + ")";
    }
    onConnectionError(message);
  }
  
  private function onConnectionError(message:String):void {
    if (readyState == CLOSED) return;
    logger.error(message);
    close(STATUS_CONNECTION_ERROR);
  }

  private function onSocketData(event:ProgressEvent):void {
    var pos:int = buffer.length;
    socket.readBytes(buffer, pos);
    for (; pos < buffer.length; ++pos) {
      if (headerState < 4) {
        // try to find "\r\n\r\n"
        if ((headerState == 0 || headerState == 2) && buffer[pos] == 0x0d) {
          ++headerState;
        } else if ((headerState == 1 || headerState == 3) && buffer[pos] == 0x0a) {
          ++headerState;
        } else {
          headerState = 0;
        }
        if (headerState == 4) {
          var headerStr:String = readUTFBytes(buffer, 0, pos + 1);
          logger.log("response header:\n" + headerStr);
          if (!validateHandshake(headerStr)) return;
          removeBufferBefore(pos + 1);
          pos = -1;
          readyState = OPEN;
          this.dispatchEvent(new WebSocketEvent("open"));
        }
      } else {
        var frame:WebSocketFrame = parseFrame();
        if (frame) {
          removeBufferBefore(frame.length);
          pos = -1;
          if (frame.rsv != 0) {
            close(1002, "RSV must be 0.");
          } else if (frame.mask) {
            close(1002, "Frame from server must not be masked.");
          } else if (frame.opcode >= 0x08 && frame.opcode <= 0x0f && frame.payload.length >= 126) {
            close(1004, "Payload of control frame must be less than 126 bytes.");
          } else {
            switch (frame.opcode) {
              case OPCODE_CONTINUATION:
                if (fragmentsBuffer == null) {
                  close(1002, "Unexpected continuation frame");
                } else {
                  fragmentsBuffer.writeBytes(frame.payload);
                  if (frame.fin) {
                    data = readUTFBytes(fragmentsBuffer, 0, fragmentsBuffer.length);
                    try {
                      this.dispatchEvent(new WebSocketEvent("message", encodeURIComponent(data)));
                    } catch (ex:URIError) {
                      close(1007, "URIError while encoding the received data.");
                    }
                    fragmentsBuffer = null;
                  }
                }
                break;
              case OPCODE_TEXT:
                if (frame.fin) {
                var data:String = readUTFBytes(frame.payload, 0, frame.payload.length);
                try {
                  this.dispatchEvent(new WebSocketEvent("message", encodeURIComponent(data)));
                } catch (ex:URIError) {
                  close(1007, "URIError while encoding the received data.");
                }
                } else {
                  fragmentsBuffer = new ByteArray();
                  fragmentsBuffer.writeBytes(frame.payload);
                }
                break;
              case OPCODE_BINARY:
                // See https://github.com/gimite/web-socket-js/pull/89
                // for discussion about supporting binary data.
                close(1003, "Received binary data, which is not supported.");
                break;
              case OPCODE_CLOSE:
                // Extracts code and reason string.
                var code:int = STATUS_NO_CODE;
                var reason:String = "";
                if (frame.payload.length >= 2) {
                  frame.payload.endian = Endian.BIG_ENDIAN;
                  frame.payload.position = 0;
                  code = frame.payload.readUnsignedShort();
                  reason = readUTFBytes(frame.payload, 2, frame.payload.length - 2);
                }
                logger.log("received closing frame");
                close(code, reason, "server");
                break;
              case OPCODE_PING:
                sendPong(frame.payload);
                break;
              case OPCODE_PONG:
                break;
              default:
                close(1002, "Received unknown opcode: " + frame.opcode);
                break;
            }
          }
        }
      }
    }
  }
  
  private function validateHandshake(headerStr:String):Boolean {
    var lines:Array = headerStr.split(/\r\n/);
    if (!lines[0].match(/^HTTP\/1.1 101 /)) {
      onConnectionError("bad response: " + lines[0]);
      return false;
    }
    var header:Object = {};
    var lowerHeader:Object = {};
    for (var i:int = 1; i < lines.length; ++i) {
      if (lines[i].length == 0) continue;
      var m:Array = lines[i].match(/^(\S+):(.*)$/);
      if (!m) {
        onConnectionError("failed to parse response header line: " + lines[i]);
        return false;
      }
      var key:String = m[1].toLowerCase();
      var value:String = StringUtil.trim(m[2]);
      header[key] = value;
      lowerHeader[key] = value.toLowerCase();
    }
    if (lowerHeader["upgrade"] != "websocket") {
      onConnectionError("invalid Upgrade: " + header["Upgrade"]);
      return false;
    }
    if (lowerHeader["connection"] != "upgrade") {
      onConnectionError("invalid Connection: " + header["Connection"]);
      return false;
    }
    if (!lowerHeader["sec-websocket-accept"]) {
      onConnectionError(
        "The WebSocket server speaks old WebSocket protocol, " +
        "which is not supported by web-socket-js. " +
        "It requires WebSocket protocol HyBi 10. " +
        "Try newer version of the server if available.");
      return false;
    }
    var replyDigest:String = header["sec-websocket-accept"]
    if (replyDigest != expectedDigest) {
      onConnectionError("digest doesn't match: " + replyDigest + " != " + expectedDigest);
      return false;
    }
    if (requestedProtocols.length > 0) {
      acceptedProtocol = header["sec-websocket-protocol"];
      if (requestedProtocols.indexOf(acceptedProtocol) < 0) {
        onConnectionError("protocol doesn't match: '" +
          acceptedProtocol + "' not in '" + requestedProtocols.join(",") + "'");
        return false;
      }
    }
    return true;
  }

  private function sendPong(payload:ByteArray):Boolean {
    var frame:WebSocketFrame = new WebSocketFrame();
    frame.opcode = OPCODE_PONG;
    frame.payload = payload;
    return sendFrame(frame);
  }
  
  private function sendFrame(frame:WebSocketFrame):Boolean {
    
    var plength:uint = frame.payload.length;
    
    // Generates a mask.
    var mask:ByteArray = new ByteArray();
    for (var i:int = 0; i < 4; i++) {
      mask.writeByte(randomInt(0, 255));
    }
    
    var header:ByteArray = new ByteArray();
    // FIN + RSV + opcode
    header.writeByte((frame.fin ? 0x80 : 0x00) | (frame.rsv << 4) | frame.opcode);
    if (plength <= 125) {
      header.writeByte(0x80 | plength);  // Masked + length
    } else if (plength > 125 && plength < 65536) {
      header.writeByte(0x80 | 126);  // Masked + 126
      header.writeShort(plength);
    } else if (plength >= 65536 && plength < 4294967296) {
      header.writeByte(0x80 | 127);  // Masked + 127
      header.writeUnsignedInt(0);  // zero high order bits
      header.writeUnsignedInt(plength);
    } else {
      fatal("Send frame size too large");
    }
    header.writeBytes(mask);
    
    var maskedPayload:ByteArray = new ByteArray();
    maskedPayload.length = frame.payload.length;
    for (i = 0; i < frame.payload.length; i++) {
      maskedPayload[i] = mask[i % 4] ^ frame.payload[i];
    }

    try {
      socket.writeBytes(header);
      socket.writeBytes(maskedPayload);
      socket.flush();
    } catch (ex:Error) {
      logger.error("Error while sending frame: " + ex.message);
      setTimeout(function():void {
        if (readyState != CLOSED) {
          close(STATUS_CONNECTION_ERROR);
        }
      }, 0);
      return false;
    }
    return true;
    
  }

  private function parseFrame():WebSocketFrame {
    
    var frame:WebSocketFrame = new WebSocketFrame();
    var hlength:uint = 0;
    var plength:uint = 0;
    
    hlength = 2;
    if (buffer.length < hlength) {
      return null;
    }

    frame.fin = (buffer[0] & 0x80) != 0;
    frame.rsv = (buffer[0] & 0x70) >> 4;
    frame.opcode  = buffer[0] & 0x0f;
    // Payload unmasking is not implemented because masking frames from server
    // is not allowed. This field is used only for error checking.
    frame.mask = (buffer[1] & 0x80) != 0;
    plength = buffer[1] & 0x7f;

    if (plength == 126) {
      
      hlength = 4;
      if (buffer.length < hlength) {
        return null;
      }
      buffer.endian = Endian.BIG_ENDIAN;
      buffer.position = 2;
      plength = buffer.readUnsignedShort();
      
    } else if (plength == 127) {
      
      hlength = 10;
      if (buffer.length < hlength) {
        return null;
      }
      buffer.endian = Endian.BIG_ENDIAN;
      buffer.position = 2;
      // Protocol allows 64-bit length, but we only handle 32-bit
      var big:uint = buffer.readUnsignedInt(); // Skip high 32-bits
      plength = buffer.readUnsignedInt(); // Low 32-bits
      if (big != 0) {
        fatal("Frame length exceeds 4294967295. Bailing out!");
        return null;
      }
      
    }

    if (buffer.length < hlength + plength) {
      return null;
    }
    
    frame.length = hlength + plength;
    frame.payload = new ByteArray();
    buffer.position = hlength;
    buffer.readBytes(frame.payload, 0, plength);
    return frame;
    
  }
  
  private function dispatchCloseEvent(wasClean:Boolean, code:int, reason:String):void {
    var event:WebSocketEvent = new WebSocketEvent("close");
    event.wasClean = wasClean;
    event.code = code;
    event.reason = reason;
    dispatchEvent(event);
  }
  
  private function removeBufferBefore(pos:int):void {
    if (pos == 0) return;
    var nextBuffer:ByteArray = new ByteArray();
    buffer.position = pos;
    buffer.readBytes(nextBuffer);
    buffer = nextBuffer;
  }
  
  private function generateKey():String {
    var vals:ByteArray = new ByteArray();
    vals.length = 16;
    for (var i:int = 0; i < vals.length; ++i) {
        vals[i] = randomInt(0, 127);
    }
    base64Encoder.reset();
    base64Encoder.encodeBytes(vals);
    return base64Encoder.toString();
  }
  
  private function readUTFBytes(buffer:ByteArray, start:int, numBytes:int):String {
    buffer.position = start;
    var data:String = "";
    for(var i:int = start; i < start + numBytes; ++i) {
      // Workaround of a bug of ByteArray#readUTFBytes() that bytes after "\x00" is discarded.
      if (buffer[i] == 0x00) {
        data += buffer.readUTFBytes(i - buffer.position) + "\x00";
        buffer.position = i + 1;
      }
    }
    data += buffer.readUTFBytes(start + numBytes - buffer.position);
    return data;
  }
  
  private function randomInt(min:uint, max:uint):uint {
    return min + Math.floor(Math.random() * (Number(max) - min + 1));
  }
  
  private function fatal(message:String):void {
    logger.error(message);
    throw message;
  }

}

}
