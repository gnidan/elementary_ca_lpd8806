#include <LPD8806.h>
#include "SPI.h"

//#define RULE 0b11111111
#define RULE 30
#define WRAP true

#if defined(USB_SERIAL) || defined(USB_SERIAL_ADAFRUIT)
// this is for teensyduino support
int dataPin = 2;
int clockPin = 1;
#else 
// these are the pins we use for the LED belt kit using
// the Leonardo pinouts
int dataPin = 16;
int clockPin = 15;
#endif

#define NUM_PIXELS 32

LPD8806 strip = LPD8806(NUM_PIXELS, dataPin, clockPin);
boolean buffer[NUM_PIXELS];
boolean nextBuffer[NUM_PIXELS];

int bufferAges[NUM_PIXELS];

int stepLength = 500;
int fadeStepCount = 10;
int fadePhaseLength = 2 * stepLength / 3;
int holdPhaseLength = 1 * stepLength / 3;  

uint32_t ageColors[] = {
  strip.Color(0, 0, 127),
  strip.Color(0, 63, 63),
  strip.Color(0, 127, 0),
  strip.Color(63, 63, 0),
  strip.Color(127, 0, 0)
};

int maxAge = 4;
  

/************************
 * MAIN ARDUINO FUNCTIONS
 ***********************/
void setup() {
    // setup random seed
  Serial.begin(9600);
  randomSeed(analogRead(0));
  Serial.println(RULE);

  /*
  
  boolean temp[32] = {1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1};
  int i;
  for(i = 0; i < 32; i++) {
    buffer[i] = temp[i];
  }
        
  */
  
  fillBufferRandomly();
  resetBufferAges();
  
  // Start up the LED strip
  strip.begin();

  // Update the strip, to start they are all 'off'
  strip.show();
}


void loop() {
  int fadeStepLength = fadePhaseLength / fadeStepCount;
  uint8_t saturation;
  int i, j;
  int percent;
  
  caStep(RULE);
  
  for (i = 1; i <= fadeStepCount; i++) {
    uint32_t color;
    percent = 100 * i / fadeStepCount;
    
    for (j=0; j < strip.numPixels(); j++) {
      int age = bufferAges[j];

      if (nextBuffer[j] && buffer[j]) {
        if (age == maxAge) {
          color = ageColors[age];
        }
        else {
          color = gradient(ageColors[age], ageColors[age + 1], percent);
        }
        
        strip.setPixelColor(j, color);
      }
      else if(nextBuffer[j] && !buffer[j]) {
        color = gradient(strip.Color(0,0,0), ageColors[0], percent);
        strip.setPixelColor(j, color); 
      }
      else if(buffer[j] && !nextBuffer[j]) {
        color = gradient(ageColors[age], strip.Color(0,0,0), percent);
        strip.setPixelColor(j, color);
      }
    }
    
    strip.show();
    delay(fadeStepLength);
  }
  
  delay(holdPhaseLength);
  updateBuffer();
}

/**********************
 * MAIN FUNCTIONS
 *********************/
void fillBufferRandomly()
{
  int i;
  int rnd;
  for (i = 0; i < NUM_PIXELS; i++)
  {
    rnd = random(2);
    buffer[i] = rnd;
  }
}

void middle()
{
  int i;
  for(i = 0; i < strip.numPixels(); i++)
  {
    buffer[i] = 0;
  }
  buffer[strip.numPixels() / 2 - 1] = 1;
}

void resetBufferAges()
{
  int i;
  for (i = 0; i < NUM_PIXELS; i++)
  {
    bufferAges[i] = 0;
  }
}

void updateBuffer()
{
  int i;
  for (i = 0; i < strip.numPixels(); i++) {
    if (buffer[i] && nextBuffer[i]) {
      if (bufferAges[i] != maxAge) {
        bufferAges[i] += 1;
      }
    }
    else {
      bufferAges[i] = 0;
    }
    
    buffer[i] = nextBuffer[i];
  }
}

/**********************
 * CA FUNCTIONS
 *********************/

void caStep(uint8_t rule) {
  int i;
  
  for (i = 0; i < strip.numPixels(); i++) {
    int on = stepForPixel(rule, i);
    nextBuffer[i] = on;
  }
}

boolean stepForPixel(uint8_t rule, int i) {
  boolean prev, cur, next;
  unsigned int pattern;
  unsigned int mask;
  
  // calculate prev, cur, next
  prev = false;
  cur = false;
  next = false;
  if (i > 0 && buffer[i - 1]) {
    prev = true;
  }
  else if (WRAP && i == 0 && buffer[strip.numPixels() - 1]) {
    prev = true;
  }
   
  if (buffer[i]) {
    cur = true;
  }
    
  if (i < strip.numPixels() - 1 && buffer[i + 1]) {
    next = true;
  }
  else if (WRAP && i == strip.numPixels() - 1 && buffer[0]) {
    next = true;
  }
   
   
   // calculate mask
   pattern = 0b0;
   if (prev)
     pattern = pattern | 0b100;
   if (cur)
     pattern = pattern | 0b10;
   if (next)
     pattern = pattern | 0b1;
   
   mask = 1 << (pattern);

   if (rule & mask)
     return true;
   else
     return false;
}

/************************
 * COLOR FUNCTIONS
 ************************/

uint8_t red(uint32_t color) {
  return (color >>  8) & 0x7f;
}

uint8_t green(uint32_t color) {
  return (color >> 16) & 0x7f;
}

uint8_t blue(uint32_t color) {
  return color         & 0x7f;
}

uint32_t gradient(uint32_t color1, uint32_t color2, int percent)
{
  uint8_t c1_r = red(color1);
  uint8_t c1_g = green(color1);
  uint8_t c1_b = blue(color1);  
  
  uint8_t c2_r = red(color2);
  uint8_t c2_g = green(color2);
  uint8_t c2_b = blue(color2);  
  
  uint8_t delta_r = (c2_r - c1_r) * percent / 100;
  uint8_t delta_g = (c2_g - c1_g) * percent / 100;
  uint8_t delta_b = (c2_b - c1_b) * percent / 100;
  
  return strip.Color(c1_r + delta_r,
                     c1_g + delta_g,
                     c1_b + delta_b);
}
