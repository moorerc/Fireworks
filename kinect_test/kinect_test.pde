import org.openkinect.*;
import org.openkinect.processing.*;
import java.util.*;
import processing.net.*;
import processing.opengl.*;

Kinect kinect;
PImage foregroundImage;
PImage backgroundLitImage;
PImage backgroundImage;
PImage fireworkImage;
PImage particleImage;
PImage flashImage;
PFont font;

// Size of kinect image
final int w = 640;
final int h = 480;

PVector centerVector = null;
PVector farthestVector = null;

// We'll use a lookup table so that we don't have to repeat the math over and over
float[] depthLookUp = new float[2048];

ArrayList<Firework> fireworkList = new ArrayList<Firework>();

// sound stuff
SurroundSystem surroundSystem;
ArrayList<Client> speakerList;
int port = 8000;
byte soundAmbientID;
int referenceDistance = 2000;
ArrayList<Byte> soundLaunchFileIDList;
ArrayList<Byte> soundExplodeFileIDList;

final int STATE_READY = 0;
final int STATE_FIRING = 1;
final int STATE_START_CALIBRATING = 2;
final int STATE_CALIBRATING = 3;

// calibration
int state = STATE_START_CALIBRATING;
int calibrateTime = 0;
final int maxCalibrateTime = 60;
final int minCalibratePoints = 1500;
double calibratedReach = 0.0;
float[] rawCalibratedReach = new float[maxCalibrateTime];
final int maxFirework = 5;
int nextFireWork = 0;

// firework data
ArrayList<color[][]> fireworkTypeList;
Server fireworkCreaterServer;
int fireworkCreaterPort = 8001;
Client fireworkCreaterClient = null;
LinkedList<Byte> byteList = new LinkedList<Byte>();
int fireworkReadyIconSize = 32;
int fireFlashFade = 255;

void setup() {
  size(1000,750,OPENGL);
  hint(ENABLE_NATIVE_FONTS);
  hint(DISABLE_OPENGL_2X_SMOOTH);
  
  // sound
  String[] hosts = { "192.168.2.5" };
  surroundSystem = new SurroundSystem(this, hosts, port);
  soundLaunchFileIDList = new ArrayList<Byte>();
  soundExplodeFileIDList = new ArrayList<Byte>();
  soundAmbientID = surroundSystem.sourceCreate((byte)0, true, referenceDistance);;
  soundLaunchFileIDList.add((byte) 1);
  soundExplodeFileIDList.add((byte) 2);
  soundExplodeFileIDList.add((byte) 3);
  soundLaunchFileIDList.add((byte) 4);
  
  
  // firework data
  fireworkTypeList = new ArrayList<color[][]>();
  fireworkCreaterServer = new Server(this, fireworkCreaterPort);
  
  noStroke();
  
  kinect = new Kinect(this);
  kinect.start();
  kinect.enableDepth(true);
  kinect.processDepthImage(false);

  foregroundImage = loadImage("grass.png");
  backgroundImage = loadImage("BG.png");
  backgroundLitImage = loadImage("BG_lit_front.png");
  fireworkImage = loadImage("ball.png");
  particleImage = loadImage("newParticle.png");
  flashImage = loadImage("big_flash.png");

  font = loadFont("font.vlw");
  
  // Lookup table for all possible depth values (0 - 2047)
  for (int i = 0; i < depthLookUp.length; i++) {
    depthLookUp[i] = rawDepthToMeters(i);
  }
  
  surroundSystem.sourceSetLocation(soundAmbientID, 0, 0, 0);
  surroundSystem.sourcePlay(soundAmbientID);
}

void serverEvent(Server server, Client client) {
  if(server == fireworkCreaterServer){
    fireworkCreaterClient = client;
    println("We have a new client: " + client.ip());
  }
}

void draw(){
  if(fireworkCreaterClient != null){
    byte[] buffer = new byte[1];
    while(fireworkCreaterClient.readBytes(buffer) > 0){
      byteList.add(buffer[0]);
    }
    if(byteList.size() >= (56 * 48 * 4 * 3)){
      println("Starting image processing");
      
      color[][] colorArray = new color[56][48];
      for(int y = 0; y < 48; y++){
        for(int x = 0; x < 56; x++){
          float[] colors = new float[3];
          for(int c = 0; c < 3; c++){
            byte[] bytes = new byte[4];
            
            for(int b = 0; b < 4; b++){
              bytes[b] = byteList.removeFirst();
            }
            
            int rawColor = ((bytes[0] << 24) & 0xff000000) + 
              ((bytes[1] << 16) & 0x00ff0000) +
              ((bytes[2] << 8) & 0x0000ff00) +
              (bytes[3] & 0x000000ff);
            colors[c] = Float.intBitsToFloat(rawColor);
          }
          
          colorArray[x][48 - y - 1] = color(colors[0], colors[1], colors[2]);
        }
      }
      fireworkTypeList.add(colorArray);
      nextFireWork = fireworkTypeList.size() - 1;
      println("Done");
    }
  }
  

  background(backgroundImage);
  if (fireFlashFade < 255) {
    tint(255, 255 - 2 * fireFlashFade);
    image(backgroundLitImage, 0, 0);
    
    //fill(255, 255, 200, (255 - 2 * fireFlashFade) / 4);
    //rect(0, 0, width, height);
    
    tint(255, (255 - 2 * fireFlashFade) / 4);
    image(flashImage, 0, 0);
    noTint();
    
    fireFlashFade += 5;
    if (fireFlashFade > 255){ 
      fireFlashFade = 255;
    }
  }
  noTint();
  
  for(int i = 0; i < (maxFirework - fireworkList.size()); i++){
    image(fireworkImage, width - (i + 1) * (fireworkReadyIconSize * 0.6) - fireworkReadyIconSize * 0.4, 0, fireworkReadyIconSize, fireworkReadyIconSize);
  }
  
  ArrayList<PVector> pointArray = getPoints();
    
  if(pointArray.size() <= minCalibratePoints){
    if(state != STATE_START_CALIBRATING){
      state = STATE_START_CALIBRATING;
      println("Starting Calibration");
    }
  }else{
    PVector newC = calculateCenter(pointArray);
    if(newC != null){
      centerVector = newC;
    }
    farthestVector = calculateFarthest(pointArray, centerVector);
      
    if(farthestVector != null){
      PVector distVec = new PVector();
      distVec.set(centerVector);
      distVec.sub(farthestVector);
      double mag = distVec.mag();
          
      if(state == STATE_START_CALIBRATING){
        state = STATE_CALIBRATING;
        calibrateTime = 0;
        rawCalibratedReach = new float[maxCalibrateTime];
      }else if(state == STATE_CALIBRATING){
        rawCalibratedReach[calibrateTime] = (float)mag;
        println("Calibrating: "+ calibrateTime);
          
        calibrateTime++;
        if(calibrateTime >= maxCalibrateTime){
          //rawCalibratedReach = sort(rawCalibratedReach);
          calibratedReach = 0.0;
          for(int i = maxCalibrateTime - 5; i < maxCalibrateTime; i++){
            calibratedReach = Math.max(calibratedReach, rawCalibratedReach[i] * 1.1);
          }
          state = STATE_READY;
          println("READY: " + calibratedReach); 
          
          textFont(font, 30);
          fill(255, 255, 255);
          pushMatrix();
            String msg = "Calibration complete";
            translate((width / 2) - (textWidth(msg) / 2), height / 2);
            text(msg, 0, 0); 
          popMatrix();
        }else{
          textFont(font, 35);
          fill(255, 255, 255);
          pushMatrix();
            String msg = "Please stand still during calibration";
            translate((width / 2) - (textWidth(msg) / 2), height / 2);
            text(msg, 0, 0); 
          popMatrix();
        }
      }else{
        if(mag >= calibratedReach){          
          PVector slope = new PVector();
          slope.set(farthestVector);
          slope.sub(centerVector);
          slope.normalize();
          slope.z *= -1.0;
          //println(slope);
          slope.mult(random(10, 20));

          if((slope.y < 0) && (fireworkList.size() < maxFirework) && (state == STATE_READY) && (fireworkTypeList.size() > 0)){
            fireworkList.add(
              new Firework(
                fireworkTypeList.get(nextFireWork), 
                centerVector, 
                slope,
                soundLaunchFileIDList.get((int) random(0, soundLaunchFileIDList.size())),
                soundExplodeFileIDList.get((int) random(0, soundLaunchFileIDList.size()))
              )
            );
            nextFireWork = (int)random(fireworkTypeList.size());
              
            state = STATE_FIRING;
          }
        }else{
          state = STATE_READY;
        }
      }
    }
  }  
  
  pushMatrix();
    translate(width / 2, height - 5);
    scale(0.4, 0.4, 0.4);
//    translate(width/2,height/2,-50);
    rotateY(PI); // to make left hand right  so its more like a mirror
    
    hint(DISABLE_DEPTH_TEST);
      ArrayList<Firework> aliveList = new ArrayList<Firework>();
      for(Firework fw : fireworkList){
        fw.step();
        if(fw.alive()){
          aliveList.add(fw);
        }
      }
      fireworkList = aliveList;
      
      fill(255, 255, 255, 60);
      ListIterator<PVector> itr = pointArray.listIterator();
      while(itr.hasNext()){
        PVector pt = itr.next();
        /*for(int i = 0; i < 4; i++){
          if(itr.hasNext()){
            pt = itr.next();
          }else{
            break;
          }
        }*/
        pushMatrix();
          //println(pt);
          translate(pt.x, pt.y,pt.z);
          rect(-5, -5, 10, 10);
        popMatrix();
      }
      /*
      if((centerVector != null) && (pointArray.size() > minCalibratePoints)){
        pushMatrix();
          textFont(font, 64);
          fill(255, 0, 0);
          String s = "" + (maxFirework - fireworkList.size());
          translate(centerVector.x, centerVector.y, centerVector.z);
          rotateY(PI);
          translate(-(textWidth(s) / 2), -(textWidth(s) / 2), 0);
          text(s, 0,0);
          //rect(-5, -5, 100, 100);
        popMatrix();
      }*/
    hint(ENABLE_DEPTH_TEST);
  popMatrix();
  image(foregroundImage, 0, 0);
}

PVector calculateCenter(ArrayList<PVector> points){
  PVector avgVector = new PVector(0, 0, 0); 
  for(PVector pt : points){
    avgVector.add(pt);
  }
  if(points.size() > 0){
    avgVector.div(points.size());
    return avgVector;
  }else{
    return null;  
  }
}

PVector calculateFarthest(ArrayList<PVector> points, PVector center){
  class CustomComparator implements Comparator<PVector> {
    private PVector center;
    
    public CustomComparator(PVector center){
      this.center = center;
    }
    
    public int compare(PVector o1, PVector o2) {
      PVector o1Vec = new PVector();
      PVector o2Vec = new PVector();
      
      o1Vec.set(center);
      o2Vec.set(center);
      
      o1Vec.sub(o1);
      o2Vec.sub(o2);
      
      double diff = o1Vec.mag() - o2Vec.mag();
      if(diff > 0){
        return 1;
      }else if(diff < 0){
        return -1;
      }else{
        return 0;
      }
    }
  }
  Collections.sort(points, new CustomComparator(center));
  return points.get(points.size() - 1);
}

ArrayList<PVector> getPoints(){
  ArrayList<PVector> vectorList = new ArrayList<PVector>();
  
  // Get the raw depth as array of integers
  int[] depth = kinect.getRawDepth();

  // We're just going to calculate and draw every 4th pixel (equivalent of 160x120)
  int skip = 4;

  //translate(width/2,height/2,-50);
  
  PVector avgVec = new PVector(0, 0 , 0);
  PVector farthestVec = null;
  int count = 0;

  float xMax = -10000.0;
  float yMax = -10000.0;
  float xMin =  10000.0;
  float yMin =  10000.0;

  for(int x = 0; x < w; x += skip) {
    for(int y = 0; y < h; y += skip) {
      int offset = x + y * w;

      // Convert kinect data to world xyz coordinate
      int rawDepth = depth[offset];
      PVector v = depthToWorld(x,y,rawDepth);

      final float factor = 200;
      PVector pt = new PVector(v.x * factor, v.y * factor,v.z * factor);
      //double mag2D = Math.sqrt(pt.x * pt.x + pt.y * pt.y);
      if(
        (pt.z < 400)
        && !((Math.abs(pt.x) > 100.0) && (Math.abs(pt.y) > 100.0))
      ){
        if(!((v.x == 0) && (v.y == 0))){
          vectorList.add(pt);
          xMax = Math.max(xMax, pt.x);
          yMax = Math.max(yMax, pt.y);
          xMin = Math.min(xMin, pt.x);
          yMin = Math.min(yMin, pt.y);
        }
      }
    }
  }
  
  int width = 1 + (int)(xMax - xMin) / 5;
  int height = 1 + (int)(yMax - yMin) / 5;
  if(width <= 0 || height <= 0){
    return new ArrayList<PVector>();
  }
  //println("@ " + width + ":" + height);
  int[][] countMap = new int[width][height];
  for(PVector v : vectorList){
    int x = (int)(v.x - xMin) / 5;
    int y = (int)(v.y - yMin) / 5;
    //println(x + ":" + y);
    countMap[x][y]++;
  }
  
  ArrayList<PVector> boxFilteredList = new ArrayList<PVector>();
  for(PVector v : vectorList){
    int x = (int)(v.x - xMin) / 5;
    int y = (int)(v.y - yMin) / 5;
    
    if(countMap[x][y] > 3){
      boxFilteredList.add(v);
    }
  }
  
  return boxFilteredList;
}

// These functions come from: http://graphics.stanford.edu/~mdfisher/Kinect.html
float rawDepthToMeters(int depthValue) {
  if (depthValue < 2047) {
    return (float)(1.0 / ((double)(depthValue) * -0.0030711016 + 3.3309495161));
  }
  return 0.0f;
}

PVector depthToWorld(int x, int y, int depthValue) {
  final double fx_d = 1.0 / 5.9421434211923247e+02;
  final double fy_d = 1.0 / 5.9104053696870778e+02;
  final double cx_d = 3.3930780975300314e+02;
  final double cy_d = 2.4273913761751615e+02;

  PVector result = new PVector();
  double depth =  depthLookUp[depthValue];//rawDepthToMeters(depthValue);
  result.x = (float)((x - cx_d) * depth * fx_d);
  result.y = (float)((y - cy_d) * depth * fy_d);
  result.z = (float)(depth);
  return result;
}

void stop() {
  surroundSystem.sourceDestroy(soundAmbientID);
  kinect.quit();
  super.stop();
}

class Firework{
  PVector locVec;
  LinkedList<PVector> prevlocsList;
  PVector slopeVec;
  int timeToSplode;
  ArrayList<Particle> particleList = new ArrayList<Particle>();
  color c;
  color[][] targetShape;
  byte soundLaunchID;
  byte soundExplodeID;
  
  Firework(color[][] targetShape, PVector orgin, PVector slope, byte soundLaunchFileID, byte soundExplodeFileID){
    prevlocsList=new LinkedList<PVector>();
    this.targetShape = targetShape;
    c = color(random(100, 200), random(100, 200), random(100, 200));
    locVec = orgin;
    slopeVec = slope;
    timeToSplode = (int) random(frameRate * 2.5, frameRate * 3.5);
    
    soundLaunchID = surroundSystem.sourceCreate(soundLaunchFileID, false, referenceDistance);
    soundExplodeID = surroundSystem.sourceCreate(soundExplodeFileID, false, referenceDistance);
    
    surroundSystem.sourceSetLocation(soundLaunchID, locVec.x, locVec.y, locVec.z);
    surroundSystem.sourcePlay(soundLaunchID);
  }
  
  void display(){
    // trail
    int opacity = 255 - 25;
    ListIterator<PVector> itr=prevlocsList.listIterator();
    while(itr.hasNext()){
      PVector temp = itr.next();
      pushMatrix();
        tint(255,opacity);
        translate(temp.x,temp.y, temp.z);
        image(fireworkImage, 0, 0);
      popMatrix();
      opacity= opacity-25;
    }
    
    // firework
    pushMatrix();
      //fill(c);
      translate(locVec.x, locVec.y, locVec.z);
      //ellipse(0, 0, 30, 30);
      image(fireworkImage, 0, 0);
    popMatrix();
    
    // add to old
    PVector vTemp = new PVector();
    vTemp.set(locVec); 
    prevlocsList.addFirst(vTemp);
    if(prevlocsList.size() > 25){
      prevlocsList.removeLast();
    }
  }
  
  void step(){
    if(timeToSplode > 0){
      locVec.add(slopeVec);
      timeToSplode--;
      
      if(timeToSplode <= 0){
        /*println(
          "(" + 
          (-1.0 * (locVec.x - centerVector.x)) + ", " +
          (locVec.y - centerVector.y) + ", " +
          (-1.0 * (locVec.z - centerVector.z)) + ")"
        );*/
        fireFlashFade = 0;
        
        surroundSystem.sourceSetLocation(
          soundExplodeID, 
          -1.0 * (locVec.x - centerVector.x), 
          0.0, //locVec.y - centerVector.y, 
          -1.0 * (locVec.z - centerVector.z)
        );
        surroundSystem.sourcePlay(soundExplodeID);
        
        for(int y = 0; y < 48; y++){
          for(int x = 0; x < 56; x++){
            color c = targetShape[x][y];
            if(
              (red(c) > 0.0) || 
              (green(c) > 0.0) ||
              (blue(c) > 0.0))
            {
              PVector slope = new PVector(
                28 - x,
                24 - y,
                0
              );
              
              slope.div(5);
              
              Particle p = new Particle(
                locVec,
                c,
                slope,
                (int) random(frameRate * 1.5, frameRate * 2.5),
                random(5, 15)
              );
              particleList.add(p);
            }
          }
        }
      }else{
        surroundSystem.sourceSetLocation(soundLaunchID, locVec.x, locVec.y, locVec.z);
      }
      
      display();
    }else if(particleList.size() > 0){
      ArrayList<Particle> aliveList = new ArrayList<Particle>();
      for(Particle p : particleList){
        p.step();
        if(p.alive()){
          aliveList.add(p);
        }
      }
      particleList = aliveList;
      if(particleList.size() <= 0){
        //surroundSystem.sourceStop(soundExplode1ID);
        surroundSystem.sourceStop(soundLaunchID);
        surroundSystem.sourceStop(soundExplodeID);
        
        surroundSystem.sourceDestroy(soundLaunchID);
        surroundSystem.sourceDestroy(soundExplodeID);
      }
    }
  }
  
  boolean alive(){
    return (timeToSplode > 0) || (particleList.size() > 0);
  }
}

class Particle{
  PVector locVec;
  PVector slopeVec;
  LinkedList<PVector> prevLocList;
  int TTL;
  int fallTTL;
  color col;
  float radius;
  final int trailLength = 10;
  final int opacityDim = 35; // amount decremented with each step
  
  Particle(PVector orgin, color c, PVector slope, int timeToLive, float r){
    locVec = new PVector();
    locVec.set(orgin);
    prevLocList = new LinkedList<PVector>();
    slopeVec = slope;
    TTL = timeToLive;
    fallTTL = 2 * timeToLive;
    col = c;
    radius = r;
  }
  
  void step(){
    if(TTL > 0){
      locVec.add(slopeVec);
      TTL--;
    }else if(fallTTL > 0){
      fallTTL--;
      PVector gravity = new PVector (0,0.1,0);
      PVector dupslope = new PVector();
      dupslope.set(slopeVec);
      slopeVec.add(gravity);
      slopeVec.normalize();
      slopeVec.mult(dupslope.mag());
      
      locVec.add(slopeVec);
    }
    
    if(alive()){
      // trail
      int opacity = 255 - opacityDim;
      ListIterator<PVector> itr=prevLocList.listIterator();
      while(itr.hasNext()){
        PVector temp=itr.next();
        if(itr.hasNext()){
          temp = itr.next();
        }
        pushMatrix();
          fill(col,opacity);
          translate(temp.x,temp.y, temp.z);
          //ellipse(0, 0, radius, radius);
          tint(col, opacity);
          //tint(255, 255, 255, opacity);
          image(particleImage, 0.0, 0.0);
        popMatrix();
        opacity = opacity - opacityDim;
      }
      
      // current location
      pushMatrix();
        fill(col,opacity);
        translate(locVec.x,locVec.y, locVec.z);
        //ellipse(0, 0, radius, radius);
        tint(col, opacity);
          //tint(255, 255, 255, opacity);
          image(particleImage, 0.0, 0.0);
      popMatrix();
         
      // add current to old
      PVector vTemp = new PVector();
      vTemp.set(locVec);
      
      prevLocList.addFirst(vTemp);
      if(prevLocList.size() > trailLength){
        prevLocList.removeLast();
      }
    }
  }
  
  boolean alive(){
    return !((TTL <= 0) && (fallTTL <= 0)); 
  }
}
