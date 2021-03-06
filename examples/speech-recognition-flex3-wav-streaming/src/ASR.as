package  
{
	/**
	 * ...
	 * @author iSpeech, Inc.
	 * @see http://www.ispeech.org/developers
	 */
	 
	import flash.display.Sprite;
	import flash.events.Event;
	import mx.containers.Canvas;
	import mx.controls.Button;
	import mx.controls.Label;
	import flash.net.FileReference;
	import flash.net.URLVariables;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.media.Microphone;
	import flash.events.*;
	import flash.text.TextField;
	import flash.display.Loader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.display.StageAlign;
	import flash.net.Socket;
	import flash.utils.Endian;
	import flash.display.MovieClip;
	 
	public class ASR extends Canvas
	{
		var recordToFile:Boolean = false;
		var timer:Timer;
		var mic:Microphone;
		var sock:Socket;
		var str:String;
		
		var volumeField:Label;
		var socketConnectedField:Label;
		var bytesWrittenField:Label;
		var currentActionField:Label;
		var speechRecognitionResultField:Label;
		var parsedResultField:Label;
		var recordButtonField:Button;
		var conversionTimeField:Label;
		
		var bytesWritten:int;
		var pcmba:ByteArray;
		var startTime:Date;
		var button:Button;
		
		public function ASR() 
		{	
			recordButtonField = new Button();
			recordButtonField.label = "Capture";
			recordButtonField.height = 20;
			recordButtonField.width = 80;
			recordButtonField.x = 0;
			recordButtonField.y = 240;
			
			recordButtonField.addEventListener(MouseEvent.MOUSE_DOWN, startRecording);
			recordButtonField.addEventListener(MouseEvent.MOUSE_UP, stopRecording);
			addChild(recordButtonField);
			
			if (Microphone.names.length == 0)
				currentActionField.text = "No microphones detected";
			
			mic = Microphone.getMicrophone(0);
			
			if (mic.muted == true){
				Security.showSettings(SecurityPanel.PRIVACY);
			}
			
			mic.rate = 8;
			mic.gain = 50;
			mic.setSilenceLevel(0);
			
			timer = new Timer(100, 0);
			timer.addEventListener(TimerEvent.TIMER, timerEvent);
			timer.start();
			
			sock = new Socket();
			sock.addEventListener(Event.CONNECT, socketConnected);
			sock.addEventListener(Event.CLOSE, socketDisconnected);
			sock.addEventListener(ProgressEvent.SOCKET_DATA, onProgress);
			
			pcmba = new ByteArray();
			pcmba.endian = Endian.LITTLE_ENDIAN;
			
			volumeField = new Label();
			volumeField.height = 20;
			volumeField.width = 400;
			volumeField.x = 0;
			volumeField.y = 80;
			addChild(volumeField);
			
			socketConnectedField = new Label();
			socketConnectedField.height = 20;
			socketConnectedField.width = 400;
			socketConnectedField.x = 0;
			socketConnectedField.y = 100;
			addChild(socketConnectedField);
			
			bytesWrittenField = new Label();
			bytesWrittenField.height = 20;
			bytesWrittenField.width = 400;
			bytesWrittenField.x = 0;
			bytesWrittenField.y = 120;
			addChild(bytesWrittenField);
			
			currentActionField = new Label();
			currentActionField.height = 20;
			currentActionField.width = 400;
			currentActionField.x = 0;
			currentActionField.y = 140;
			addChild(currentActionField);
			
			speechRecognitionResultField = new Label();
			speechRecognitionResultField.height = 20;
			speechRecognitionResultField.width = 400;
			speechRecognitionResultField.x = 0;
			speechRecognitionResultField.y = 160;
			addChild(speechRecognitionResultField);
			
			parsedResultField = new Label();
			parsedResultField.height = 20;
			parsedResultField.width = 400;
			parsedResultField.x = 0;
			parsedResultField.y = 180;
			addChild(parsedResultField);
			
			conversionTimeField = new Label();
			conversionTimeField.height = 20;
			conversionTimeField.width = 400;
			conversionTimeField.x = 0;
			conversionTimeField.y = 200;
			addChild(conversionTimeField);
				
			if (Microphone.names.length == 0)
				currentActionField.text = "Last event: No microphones detected";
		}
		
		public function moved(e:Event):void {
			
			if (mic.muted == true)
				Security.showSettings(SecurityPanel.PRIVACY);
			else
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, moved);
		}
		
		private function socketConnected(e:Event) {
			currentActionField.text = "Last event: Socket connected";
			
			str = "POST /api/rest/";
			str += "?apikey=developerdemokeydeveloperdemokey";
			str += "&freeform=3";
			str += "&output=rest";
			str += "&deviceType=flashSDK";
			str += "&action=recognize";
			str += "&content-type=audio/x-wav ";
			str += "HTTP/1.1\r\n";
			str += "X-Stream: http\r\n";
			str += "Content-Type: audio/x-wav\r\n";
			str += "Host: api.ispeech.org\r\n\r\n";
			bytesWritten += str.length;
			sock.writeUTFBytes(str);
			sock.flush();
		}
		
		private function startRecording(e:Event=null) {
			mic.addEventListener(SampleDataEvent.SAMPLE_DATA, micSampleDataHandler);
			recordButtonField.label = "Capturing";
			sock.connect('api.ispeech.org', 80);
		}
		
		private function micSampleDataHandler(event:SampleDataEvent) {

			currentActionField.text = "Last event: Received microphone data";
			
			while (sock.connected && event.data.bytesAvailable) {
				var floatsample:Number = event.data.readFloat();
				var shortsample:Number=floatsample*(Math.pow(2,15)-1) //downsamples float to a signed short/double
				pcmba.writeShort(shortsample);
			}
			if (sock.connected){
				sock.writeInt(pcmba.length);
				sock.writeBytes(pcmba);
				bytesWritten += pcmba.length;
				pcmba.clear();
				sock.flush();
			}
			else
				trace('not yet connected');
		}	
		
		public function timerEvent(e:Event):void {
			volumeField.text = "Microphone activity level: " + mic.activityLevel.toString();
			socketConnectedField.text = "Socket connected: " + sock.connected;
			bytesWrittenField.text = "Bytes written: " + bytesWritten;
		}
		
		private function onProgress(e:ProgressEvent) {
			mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, micSampleDataHandler);
			currentActionField.text = "Last event: Result received";
			var string:String = sock.readUTFBytes(e.bytesLoaded);
			string = string.substr(string.indexOf("\r\n\r\n") + 4, string.length);
			speechRecognitionResultField.text = "Raw result: " + string;
			var urlVariables:URLVariables = new URLVariables(string);
			parsedResultField.text = "Parsed Result: Text: " + urlVariables.text + ", Confidence: " + urlVariables.confidence;
		}
		
		private function stopRecording(e:Event):void {
			mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, micSampleDataHandler);
			recordButtonField.label = "Capture";
			currentActionField.text = "Last event: Stopped Recording";
			
			sock.writeInt(pcmba.length);
			sock.writeBytes(pcmba);
			
			if (recordToFile == true){
				var fileRef:FileReference = new FileReference();
				fileRef.save(pcmba, "filename.pcm");
			}
			
			sock.writeInt(0);
			sock.flush();
			startTime = new Date();
		}
		
		private function socketDisconnected(e:Event) {
			var currentDate:Date = new Date();
			conversionTimeField.text = "Conversion took: " + (currentDate.time-startTime.time) + " milliseconds";
		}
	}
}