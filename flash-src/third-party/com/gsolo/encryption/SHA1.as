package com.gsolo.encryption {
	public class SHA1 {
		/*
		 * A JavaScript implementation of the Secure Hash Algorithm, SHA-1, as defined
		 * in FIPS PUB 180-1
		 * Version 2.1a Copyright Paul Johnston 2000 - 2002.
		 * Other contributors: Greg Holt, Andrew Kepert, Ydnar, Lostinet
		 * Distributed under the BSD License
		 * See http://pajhome.org.uk/crypt/md5 for details.
		 *
		 * Converted to AS3 By Geoffrey Williams
		 */
		
		/*
		 * Configurable variables. You may need to tweak these to be compatible with
		 * the server-side, but the defaults work in most cases.
		 */
		 
		public static const HEX_FORMAT_LOWERCASE:uint = 0;
		public static const HEX_FORMAT_UPPERCASE:uint = 1;
		
		public static const BASE64_PAD_CHARACTER_DEFAULT_COMPLIANCE:String = "";
		public static const BASE64_PAD_CHARACTER_RFC_COMPLIANCE:String = "=";
		
		public static const BITS_PER_CHAR_ASCII:uint = 8;
		public static const BITS_PER_CHAR_UNICODE:uint = 8;
		 
		public static var hexcase:uint = 0;  /* hex output format. 0 - lowercase; 1 - uppercase        */
		public static var b64pad:String  = ""; /* base-64 pad character. "=" for strict RFC compliance   */
		public static var chrsz:uint   = 8;  /* bits per input character. 8 - ASCII; 16 - Unicode      */
		
		public static function encrypt (string:String):String {
			return hex_sha1 (string);
		}
		
		/*
		 * These are the functions you'll usually want to call
		 * They take string arguments and return either hex or base-64 encoded strings
		 */
		public static function hex_sha1 (string:String):String {
			return binb2hex (core_sha1( str2binb(string), string.length * chrsz));
		}
		
		public static function b64_sha1 (string:String):String {
			return binb2b64 (core_sha1 (str2binb (string), string.length * chrsz));
		}
		
		public static function str_sha1 (string:String):String {
			return binb2str (core_sha1 (str2binb (string), string.length * chrsz));
		}
		
		public static function hex_hmac_sha1 (key:String, data:String):String {
			return binb2hex (core_hmac_sha1 (key, data));
		}
		
		public static function b64_hmac_sha1 (key:String, data:String):String {
			return binb2b64 (core_hmac_sha1 (key, data));
		}
		
		public static function str_hmac_sha1 (key:String, data:String):String {
			return binb2str (core_hmac_sha1 (key, data));
		}
		
		/*
		 * Perform a simple self-test to see if the VM is working
		 */
		public static function sha1_vm_test ():Boolean {
		  return hex_sha1 ("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d";
		}
		
		/*
		 * Calculate the SHA-1 of an array of big-endian words, and a bit length
		 */
		public static function core_sha1 (x:Array, len:Number):Array {
			/* append padding */
			x[len >> 5] |= 0x80 << (24 - len % 32);
			x[((len + 64 >> 9) << 4) + 15] = len;
		
			var w:Array = new Array(80);
			var a:Number =  1732584193;
			var b:Number = -271733879;
			var c:Number = -1732584194;
			var d:Number =  271733878;
			var e:Number = -1009589776;
			
			for(var i:Number = 0; i < x.length; i += 16) {
				var olda:Number = a;
				var oldb:Number = b;
				var oldc:Number = c;
				var oldd:Number = d;
				var olde:Number = e;
				
				for(var j:Number = 0; j < 80; j++) {
					if(j < 16) w[j] = x[i + j];
				     else w[j] = rol(w[j-3] ^ w[j-8] ^ w[j-14] ^ w[j-16], 1);
					var t:Number = safe_add (safe_add (rol (a, 5), sha1_ft (j, b, c, d)), safe_add (safe_add (e, w[j]), sha1_kt (j)));
					e = d;
					d = c;
					c = rol(b, 30);
					b = a;
					a = t;
				}
				
				a = safe_add(a, olda);
				b = safe_add(b, oldb);
				c = safe_add(c, oldc);
				d = safe_add(d, oldd);
				e = safe_add(e, olde);
			}
			  
			return [a, b, c, d, e];
		}
		
		/*
		 * Perform the appropriate triplet combination function for the current
		 * iteration
		 */
		public static function sha1_ft (t:Number, b:Number, c:Number, d:Number):Number {
			if(t < 20) return (b & c) | ((~b) & d);
			if(t < 40) return b ^ c ^ d;
			if(t < 60) return (b & c) | (b & d) | (c & d);
			return b ^ c ^ d;
		}
		
		/*
		 * Determine the appropriate additive constant for the current iteration
		 */
		public static function sha1_kt (t:Number):Number {
			return (t < 20) ?  1518500249 : (t < 40) ?  1859775393 : (t < 60) ? -1894007588 : -899497514;
		}
		
		/*
		 * Calculate the HMAC-SHA1 of a key and some data
		 */
		public static function core_hmac_sha1 (key:String, data:String):Array {
		  var bkey:Array = str2binb (key);
		  if (bkey.length > 16) bkey = core_sha1 (bkey, key.length * chrsz);
		
		  var ipad:Array = new Array(16), opad:Array = new Array(16);
		  for(var i:Number = 0; i < 16; i++) {
			ipad[i] = bkey[i] ^ 0x36363636;
			opad[i] = bkey[i] ^ 0x5C5C5C5C;
		  }
		
		  var hash:Array = core_sha1 (ipad.concat (str2binb(data)), 512 + data.length * chrsz);
		  return core_sha1 (opad.concat (hash), 512 + 160);
		}
		
		/*
		 * Add integers, wrapping at 2^32. This uses 16-bit operations internally
		 * to work around bugs in some JS interpreters.
		 */
		public static function safe_add (x:Number, y:Number):Number {
			var lsw:Number = (x & 0xFFFF) + (y & 0xFFFF);
			var msw:Number = (x >> 16) + (y >> 16) + (lsw >> 16);
			return (msw << 16) | (lsw & 0xFFFF);
		}
		
		/*
		 * Bitwise rotate a 32-bit number to the left.
		 */
		public static function rol (num:Number, cnt:Number):Number {
			return (num << cnt) | (num >>> (32 - cnt));
		}
		
		/*
		 * Convert an 8-bit or 16-bit string to an array of big-endian words
		 * In 8-bit function, characters >255 have their hi-byte silently ignored.
		 */
		public static function str2binb (str:String):Array {
		  var bin:Array = new Array ();
		  var mask:Number = (1 << chrsz) - 1;
		  for (var i:Number = 0; i < str.length * chrsz; i += chrsz) bin[i>>5] |= (str.charCodeAt (i / chrsz) & mask) << (32 - chrsz - i%32);
		  return bin;
		}
		
		/*
		 * Convert an array of big-endian words to a string
		 */
		public static function binb2str (bin:Array):String {
			var str:String = "";
			var mask:Number = (1 << chrsz) - 1;
			for (var i:Number = 0; i < bin.length * 32; i += chrsz) str += String.fromCharCode((bin[i>>5] >>> (32 - chrsz - i%32)) & mask);
			return str;
		}
		
		/*
		 * Convert an array of big-endian words to a hex string.
		 */
		public static function binb2hex (binarray:Array):String {
			var hex_tab:String = hexcase ? "0123456789ABCDEF" : "0123456789abcdef";
			var str:String = "";
			for(var i:Number = 0; i < binarray.length * 4; i++) {
			str += hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8+4)) & 0xF) +
			          hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8  )) & 0xF);
			}
			return str;
		}
		
		/*
		 * Convert an array of big-endian words to a base-64 string
		 */
		public static function binb2b64 (binarray:Array):String {
			var tab:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
			var str:String = "";
			for(var i:Number = 0; i < binarray.length * 4; i += 3) {
				var triplet:Number = (((binarray[i   >> 2] >> 8 * (3 -  i   %4)) & 0xFF) << 16)
		                | (((binarray[i+1 >> 2] >> 8 * (3 - (i+1)%4)) & 0xFF) << 8 )
		                |  ((binarray[i+2 >> 2] >> 8 * (3 - (i+2)%4)) & 0xFF);
				for(var j:Number = 0; j < 4; j++) {
					if (i * 8 + j * 6 > binarray.length * 32) str += b64pad;
					else str += tab.charAt((triplet >> 6*(3-j)) & 0x3F);
				}
			}
			return str;
		}		
	}
}
