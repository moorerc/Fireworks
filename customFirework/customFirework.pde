import processing.net.*;

PImage img;
PImage menuImage;
PImage emptyWarning;
PImage buttonOutline;
PImage tooManyWarning;
int warning_type = 0;
int brushStroke = 10;
int menu_x = 80;
int menu_y = 480;
int R = 256;
int B = 256;
int G = 256;

boolean dialog_up = false;

String server = "67.194.41.99";
int port = 8001;

color [][] FW = new color[56][48];
color [][] saveColors = new color[200][100];

PFont font;
PFont font2;


void setup() {
  background(0,0,0);
  size(640,480);
  
  // Initialize Menu Images
  menuImage = loadImage("menu_bar.png");
  buttonOutline = loadImage("menu_select.png");
  emptyWarning = loadImage("menu_empty.png");
  tooManyWarning = loadImage("menu_too_many_pixels.png");
  image(menuImage,0,0,menu_x,menu_y);
  image(buttonOutline,18,313,43,43);
  font = loadFont("Arial-Black-10.vlw");
}

void draw() {
  
}

void mouseClicked() {
    if (dialog_up == false) {
      if ((mouseX < 69)&&(mouseX > 10)&&(mouseY < 437)&&(mouseY > 414)){
          // Clear Button is Pressed
          color cp = color(0,0,0);
          fill(cp);
          rect(menu_x, 0, width-menu_x, height);
      }
      else if ((mouseX < 69)&&(mouseX > 10)&&(mouseY < 467)&&(mouseY > 444)) {
        // Submit Button is Pressed
          loadPixels();
          boolean all_blank = true;
          int num_colored = 0;

          for (int j = 0; j < 48; j++){
            for (int i = 0; i < 56; i++){          
              int loc = i*10 + j*(width * 10) + menu_x;
              FW[i][j] = pixels[loc];
                if ((red(pixels[loc]) != 0)&&(green(pixels[loc])!=0)&&(blue(pixels[loc])!=0)){
                  all_blank = false;
                  num_colored = num_colored + 1;
                }
            }
          }
          
          if ((all_blank == false)&&(num_colored <= 600)){
            Client C = new Client(this, server, port);
            for (int a = 0; a < 48; a++){
               for (int b = 0; b < 56; b++) {
                  byte [] bytes = new byte[4];
                  floatToBytes(red(FW[b][a]),bytes);
                  C.write(bytes);
                  floatToBytes(green(FW[b][a]),bytes);
                  C.write(bytes);
                  floatToBytes(blue(FW[b][a]),bytes);
                  C.write(bytes);
               }
            }     
            C.stop();
                    
            color cp = color(0,0,0);
            fill(cp);
            rect(menu_x, 0, width-menu_x, height);
          }
          
          if (all_blank == true){
             // User Tries to Submit a Blank Image
             sendDialog (1);            
          }
          if (num_colored > 600){
             loadPixels();
             int loc;
             for ( int b=0; b < 100; b++){
                for (int a=0; a < 200; a++){
                  loc = width*(189) + 220 + width*(b) + a;
                  saveColors[a][b] = pixels[loc];
                }
             }
            
            // User Tries to Submit an Image with Too Many Colored Pixels
             sendDialog (2); 
             //font = loadFont("Arial-Black-10.vlw");
             textFont(font);
             fill(0,0,0);
             int over = num_colored - 600;
             text(num_colored, 335,210);
             text("600",341,228);
             //text("Try Again!",menu_x + (width - menu_x)/2 - 25, height/2);
          }   
        
      }
      else if ( (mouseX < ((0.75)*(menu_x))) && (mouseX > ((0.25)*menu_x))){
        // User Clicks in Menu
        if ( (mouseY > (15)) && (mouseY < (15+38))){
          // Red
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,13,43,43);
           R = 229;
          G = 9;
          B = 9;
        }
        if ( (mouseY > (65)) && (mouseY < (65+38))){
          // Orange
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,63,43,43);
           R = 229;
           G = 120;
           B = 9;
        }  
        else if ( (mouseY > (115)) && (mouseY < (115+38))){
          // Yellow
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,113,43,43);
          R = 225;
          G = 229;
          B = 9;
        }
        else if ( (mouseY > (165)) && (mouseY < (165+38))){
          // Green
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,163,43,43);
          R = 48;
          G = 229;
          B = 9;
        }
        else if ( (mouseY > (215)) && (mouseY < (215+38))){
          // Blue
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,213,43,43);
          R = 9;
          G = 29;
          B = 229;
        }
        else if ( (mouseY > (265)) && (mouseY < (265+38))){
          // Purple
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,263,43,43);
          R = 162;
          G = 9;
          B = 229;
        }
        else if ( (mouseY > (315)) && (mouseY < (315+38))){
          // White
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,313,43,43);
          R = 256;
          G = 256;
          B = 256;
        }
        else if ( (mouseY > (367)) && (mouseY < (367+38))){
          // Black - Eraser Button
          image(menuImage,0,0,menu_x,menu_y);
          image(buttonOutline,18,365,43,43);
          R = 0;
          G = 0;
          B = 0;
        } 
    }
  else if((mouseX < (width - (brushStroke/2)))&&(mouseX >= menu_x)&&(mouseY<(height-(brushStroke/2))) &&(mouseY>=(0+(brushStroke/2)))) {
    // User Clicks Within Drawing Space
    noStroke();
    
    int mx = mouseX;
    int my = mouseY;
    
    mx = mouseX - (mouseX%brushStroke);
    my = mouseY - (mouseY%brushStroke);

    color cp = color(R,G,B);
    fill(cp);
    rect(mx,my,brushStroke,brushStroke);  
  }
 }
 if (dialog_up == true) {
   // Dialog Box is Currently Being Displayed
    if ((mouseX < 355)&&(mouseX > 285)&&(mouseY < 282)&&(mouseY > 254)){
      // If Okay Button is Clicked
       dialog_up = false;
       int loc;
       if (warning_type == 1){
            color cp = color(0,0,0);
            fill(cp);
            rect(menu_x, 0, width-menu_x, height);
         
       }
       if (warning_type == 2){
         //rect(menu_x, 0, width-menu_x, height);
          for ( int b=0; b < 100; b++){
            for (int a=0; a < 200; a++){
              loc = width*(189) + 220 + width*b + a;
              pixels[loc] = saveColors[a][b];
            }
          }
          updatePixels();
       }
       warning_type = 0;
    }

 }   
}

void mouseDragged() {
 if (dialog_up == false) { 
  if ((mouseX < (menu_x))&&(mouseY < (menu_y)) ){
    // Mouse is Dragged in Menu Area - Do Nothing
  }
  else if((mouseX < (width - (brushStroke/2)))&&(mouseX >= 0)&&(mouseY<(height-(brushStroke/2))) &&(mouseY>=(0+(brushStroke/2)))) {
    // Mouse is Dragged in Drawing Space
    noStroke();
    int mx = mouseX;
    int my = mouseY;
    mx = mouseX - (mouseX%brushStroke);
    my = mouseY - (mouseY%brushStroke);
    color cp = color(R,G,B);
    fill(cp);
    rect(mx,my,brushStroke,brushStroke);  
  }
 }
}

void intToBytes( int num, byte[] bytes) {
   bytes[0] = (byte)((num >> 24) & 0xff);
   bytes[1] = (byte)((num >> 16) & 0xff);
   bytes[2] = (byte)((num >> 8) & 0xff);
   bytes[3] = (byte)((num) & 0xff);
}

void floatToBytes ( float num, byte[] bytes) {
   int n = Float.floatToIntBits(num);
   intToBytes(n, bytes); 
}

void sendDialog (int type) {
   dialog_up = true;
 
  if (type == 1){
     // Empty Image Warning
     warning_type = 1;
     image(emptyWarning,220,190,200,100);
  }
  if (type == 2){
     // Too Many Colored Pixels Warning
     warning_type = 2;
     image(tooManyWarning,220,190,200,100);
  }
}

