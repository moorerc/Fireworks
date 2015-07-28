import com.jogamp.openal.sound3d.*;
import com.jogamp.openal.eax.*;
import com.jogamp.openal.*;
import com.jogamp.openal.util.*;
import jogamp.openal.*;
import java.util.*;
import processing.net.*;

final byte SOURCE_CREATE = 0;
final byte SOURCE_DESTROY = 1;
final byte SOURCE_PLAY = 2;
final byte SOURCE_STOP = 3;
final byte SOURCE_MOVE = 4;
final byte SOURCE_SET_LOCATION = 5;


HashMap<Byte, Buffer> soundMap;
HashMap<Byte, Source> sourceMap;
OALUtil audioSys;
Listener listener;

String path = "C:\\Users\\Sara\\School\\College\\UofM\\Junior\\Fall\\EECS 498\\processing\\speaker_server\\data\\";
int port = 8000;
Server server;

void setup(){
  size(64, 64);
  server = new Server(this, port);
  
  soundMap = new HashMap<Byte, Buffer>();
  sourceMap = new HashMap<Byte, Source>();
  audioSys = new OALUtil();
  
  try {
    soundMap.put((byte)0, audioSys.loadBuffer(path + "ambience_long.wav"));
    soundMap.put((byte)1, audioSys.loadBuffer(path + "firework_screamer.wav"));
    soundMap.put((byte)2, audioSys.loadBuffer(path + "big_explosion.wav"));
    soundMap.put((byte)3, audioSys.loadBuffer(path + "explosion2.wav"));
    soundMap.put((byte)4, audioSys.loadBuffer(path + "screamer2.wav"));
  }  
  catch (Exception e) {
    e.printStackTrace();
  }
  
  listener = audioSys.getListener();
  listener.setGain(1);
  listener.setPosition(0.0, 0.0, 0.0); // set fake center
}

void draw(){
 try{
    Client client = null;
    
    while(client == null){
      client = server.available();
    }
    
    byte[] buffer = new byte[1];;
    LinkedList<Byte> byteArray = null;
    byte packetSize = 0;
    
    while(true){
      if(client.readBytes(buffer) > 0){
        if(byteArray == null){
          byteArray = new LinkedList<Byte>();
          packetSize = buffer[0];
        }else{
          byteArray.add(buffer[0]);
        }
        
        if(byteArray.size() >= packetSize){
          packetSize = 0;
          /*
          println("start");
          for(byte b : byteArray){
            println(b);
          }
          println("end");
          */
          processPacket(byteArray);
          byteArray = null;
        }
      }
    }  
  }catch(Exception e){
    e.printStackTrace();
    exit();
  }
}

void processPacket(LinkedList<Byte> bytes){
  //println(bytes.size());
  byte instructionCode = bytes.removeFirst();
  byte[] packet = new byte[bytes.size()];
  
  int i = 0;
  for(byte b : bytes){
    packet[i] = b;
    i++;  
  }
  
  switch(instructionCode){
    case SOURCE_CREATE:
      sourceCreate(packet);
      break;
    case SOURCE_DESTROY:
      sourceDestroy(packet);
      break;
    case SOURCE_PLAY:
      sourcePlay(packet);
      break;
    case SOURCE_STOP:
      sourceStop(packet);
      break;
    case SOURCE_MOVE:
      sourceMove(packet);
      break;
    case SOURCE_SET_LOCATION:
      sourceSetLocation(packet);
      break;
  }
}

void sourceCreate(byte[] packet){
  byte id = packet[0];
  byte fileID = packet[1];
  boolean loop = byteToBoolean(packet[2]);
  int referenceDistance = bytesToInt(packet, 3);
  println("C: " + id);
  
  Source s = audioSys.createSource(soundMap.get(fileID));
  s.setLooping(loop);
  s.setGain(1);
  s.setReferenceDistance(referenceDistance);
  
  sourceMap.put(id, s);
}

void sourceDestroy(byte[] packet){
  byte id = packet[0];
  println("D: " + id);
  sourceMap.remove(id).delete();
}

void sourcePlay(byte[] packet){
  byte id = packet[0];
  println("P: " + id);
  sourceMap.get(id).play();
}

void sourceStop(byte[] packet){
  byte id = packet[0];
  println("S: " + id);
  sourceMap.get(id).stop();
}

void sourceMove(byte[] packet){
  byte id = packet[0];
  println("M: " + id);
  float x = bytesToFloat(packet, 1);
  float y = bytesToFloat(packet, 5);
  float z = bytesToFloat(packet, 9);

  Source s = sourceMap.get(id);
  s.setPosition(s.getPosition().v1 + x, s.getPosition().v2 + y, s.getPosition().v3 + z);
}

void sourceSetLocation(byte[] packet){
  byte id = packet[0];
  println("Set: " + id);
  float x = bytesToFloat(packet, 1);
  float y = bytesToFloat(packet, 5);
  float z = bytesToFloat(packet, 9);
  
  //println("(" + x + ", " + y + ", " + z + ")");

  Source s = sourceMap.get(id);
  s.setPosition(x, y, z);  
}

boolean byteToBoolean(byte b){
  return b > 0;
}

int bytesToInt(byte[] bytes, int offset){
  return 
    ((bytes[0 + offset] << 24) & 0xff000000) + 
    ((bytes[1 + offset] << 16) & 0x00ff0000) +
    ((bytes[2 + offset] << 8) & 0x0000ff00) +
    (bytes[3 + offset] & 0x000000ff);
}

float bytesToFloat(byte[] bytes, int offset){
  return Float.intBitsToFloat(bytesToInt(bytes, offset));
}

public void stop() {
  for(Source s : sourceMap.values()){
    s.delete();
  }
  sourceMap = null;

  if (audioSys != null) {
    audioSys.cleanup();
    audioSys = null;
  }
}
