import java.util.*;
import processing.core.*;
import processing.net.*;

public class SurroundSystem{
  private final byte SOURCE_CREATE = 0;
  private final byte SOURCE_DESTROY = 1;
  private final byte SOURCE_PLAY = 2;
  private final byte SOURCE_STOP = 3;
  private final byte SOURCE_MOVE = 4;
  private final byte SOURCE_SET_LOCATION = 5;

  private PApplet parent;

  private ArrayList<Client> speakerList;
  private HashSet<Byte> availableIDs;

  public SurroundSystem(PApplet parent, String[] hosts, int port){
    this.parent = parent;
    speakerList = new ArrayList<Client>();
    for(String h : hosts){
      speakerList.add(new Client(parent, h, port));
    }
    
    availableIDs = new HashSet<Byte>();
    for(byte i = 0; i < 64; i++){
      availableIDs.add(i);
    }
    /*
    for(int j = 1; j <= 3; j++){
      byte[] bs = new byte[5];
      for(int i = 0; i < bs.length; i++){
        bs[i] = (byte)(i * j);
      }
      
      sendCommand(bs);
    }
    */
  }
    
  public byte sourceCreate(byte fileID, boolean loop, int referenceDistance){
    byte ret = availableIDs.iterator().next();
    availableIDs.remove(ret);
    
    byte[] cmd = new byte[8];
    cmd[0] = SOURCE_CREATE;
    cmd[1] = ret;
    cmd[2] = fileID;
    cmd[3] = booleanToByte(loop);
    intToBytes(referenceDistance, cmd, 4);
    sendCommand(cmd);
    return ret;
  }
  
  public void sourceDestroy(byte id){
    byte[] cmd = new byte[2];
    cmd[0] = SOURCE_DESTROY;
    cmd[1] = id;
    availableIDs.add(id);
    sendCommand(cmd);
  }
  
  public void sourcePlay(byte id){
    byte[] cmd = new byte[2];
    cmd[0] = SOURCE_PLAY;
    cmd[1] = id;
    
    sendCommand(cmd);
  }
  
  public void sourceStop(byte id){
    byte[] cmd = new byte[2];
    cmd[0] = SOURCE_STOP;
    cmd[1] = id;
    sendCommand(cmd);    
  }
  
  public void sourceMove(byte id, float x, float y, float z){
    byte[] cmd = new byte[14];
    cmd[0] = SOURCE_MOVE;
    cmd[1] = id;
    floatToBytes(x, cmd, 2);
    floatToBytes(y, cmd, 6);
    floatToBytes(z, cmd, 10);
    sendCommand(cmd);
  }
  
  public void sourceSetLocation(byte id, float x, float y, float z){
    byte[] cmd = new byte[14];
    cmd[0] = SOURCE_SET_LOCATION;
    cmd[1] = id;
    floatToBytes(x, cmd, 2);
    floatToBytes(y, cmd, 6);
    floatToBytes(z, cmd, 10);
    sendCommand(cmd);
  }

  private void sendCommand(byte[] cmd){
    for(Client c : speakerList){
      c.write((byte)cmd.length + 1);
      c.write(cmd);
    }
    for(Client c : speakerList){
      c.write((byte) 0);
    }
  }
  
  private byte booleanToByte(boolean b){
    return (byte) ((b) ? 1 : 0);
  }
  
  private void intToBytes(int num, byte[] bytes, int offset){
    bytes[0 + offset] = (byte) ((num >> 24) & 0xff);
    bytes[1 + offset] = (byte) ((num >> 16) & 0xff);
    bytes[2 + offset] = (byte) ((num >> 8) & 0xff);
    bytes[3 + offset] = (byte) (num & 0xff);
  }
  
  private void floatToBytes(float num, byte[] bytes, int offset){
    int n = Float.floatToIntBits(num);
    intToBytes(n, bytes, offset);
  }
}

