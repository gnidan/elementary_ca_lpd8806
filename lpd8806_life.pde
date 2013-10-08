#include <LPD8806.h>
#include "SPI.h"
#include "lpd8806_life.h"

/*******************************
 * TEENSYDUINO & LED BELT SETUP
 ******************************/
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

/********************
 * RULES
 *******************/
#define WRAP true

rule_t rules[] = {
  110,
  38,
  30,
  150,
  73,
  15,
  45,
  105,
  106,
  184
};
int numRules = 10;


/******************************
 * COLOR PALETTE
 *****************************/
#define MAX_AGE 4

color_t ageColors[][MAX_AGE + 1] = {
  {
    strip.Color(84, 11, 127),
    strip.Color(127, 59, 4),
    strip.Color(127, 126, 4),
    strip.Color(127, 10, 72),
    strip.Color(4, 127, 123)
  },
  {
    strip.Color(0, 0, 127),
    strip.Color(0, 63, 63),
    strip.Color(0, 127, 0),
    strip.Color(63, 63, 0),
    strip.Color(127, 0, 0)
  },
  {
    strip.Color(0, 102, 00),
    strip.Color(103, 0, 58),
    strip.Color(127, 58, 0),
    strip.Color(127, 0, 0),
    strip.Color(127, 127, 127)
  }
};


int numColorPalettes = 3;

/*******************************
 * TIMING
 ******************************/

// How long should each step take? (ms)
int stepLength = 500;

// Granularity of color fading; how many intermediate colors should the
// fade pass through
int fadeStepCount = 10;

// Two phases per step: fade in, then hold. Specify timings here:
int fadePhaseLength = 2 * stepLength / 3;
int holdPhaseLength = stepLength / 3;  

int fadeStepLength = fadePhaseLength / fadeStepCount;

// Cycling through rules.
//   ruleCycleTime: how long we should do each rule for.
int ruleCycleTime = 15000;
int caStepNumber = 0;
int ruleSteps = ruleCycleTime / stepLength;
int currentRule = rules[(caStepNumber / ruleSteps) % numRules];


/*******************************
 * MEMORY ALLOCATION
 ******************************/
boolean buffer[NUM_PIXELS];
boolean nextBuffer[NUM_PIXELS];
int bufferAges[NUM_PIXELS];


/************************
 * MAIN ARDUINO FUNCTIONS
 ***********************/
void setup()
{
  // setup random seed
  Serial.begin(9600);
  randomSeed(analogRead(0));

  /*
  boolean temp[32] = {1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1,
   1, 1, 1, 1, 1, 1, 1, 1};
   int i;
   for(i = 0; i < 32; i++) {
   buffer[i] = temp[i];
   }*/


  fillBufferRandomly();
  resetBufferAges();

  // Start up the LED strip
  strip.begin();

  // Update the strip, to start they are all 'off'
  strip.show();
}

void loop()
{
  int i, j;
  int prevRule = currentRule;
  int fadePercent;
  color_t *currentPalette;
  color_t color;

  // figure out the current rule
  currentRule = rules[(caStepNumber / ruleSteps) % numRules];
  
  // figure out the palette to use for the current rule
  currentPalette = ageColors[(caStepNumber / ruleSteps) % numColorPalettes];
  
  if(prevRule != currentRule) {
    // if we're resetting to a new rule, let's reset the buffer.
    fillBufferRandomly();
    resetNextBuffer();
    resetBufferAges();
    
    // debugging for funsies
    Serial.println( (int) currentRule );
  }

  caStepNumber++;
  
  // One step!
  caStep(currentRule);

  // Now start the fade. We've already calculated the length of time for each step
  // in the fade, and how many steps we have to complete the fade:
  //     for each step in the fade:
  for (i = 1; i <= fadeStepCount; i++) {
    // how far through the fade are we?
    fadePercent = 100 * i / fadeStepCount;
    
    //   for each pixel on the strip:
    for (j=0; j < strip.numPixels(); j++) {
      // how long has the pixel been alive?
      int age = bufferAges[j];
      
      // if the pixel is staying alive, fade from its current age to its next age
      if (nextBuffer[j] && buffer[j]) {
        if (age == MAX_AGE) {       // after awhile, the pixel won't age any more.
          color = currentPalette[age];
        }
        else {
          color = gradient(currentPalette[age], currentPalette[age + 1], fadePercent);
        }

        strip.setPixelColor(j, color);
      }
      
      // else if the pixel is being born, fade in
      else if(nextBuffer[j] && !buffer[j]) {
        color = gradient(strip.Color(0,0,0), currentPalette[0], fadePercent);
        strip.setPixelColor(j, color); 
      }
      
      // else if the pixel is dying, fade out
      else if(buffer[j] && !nextBuffer[j]) {
        color = gradient(currentPalette[age], strip.Color(0,0,0), fadePercent);
        strip.setPixelColor(j, color);
      }
    }
    
    
    // show the strip and pause for the the length of time for each step in the fade
    strip.show();
    delay(fadeStepLength);
  }
  
  // after we do the fade, we hold the display for an amount of time
  delay(holdPhaseLength);
  
  // update buffer with the contents of nextBuffer
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

void resetBuffer()
{
  int i;
  for (i = 0; i < NUM_PIXELS; i++)
  {
    buffer[i] = 0;
  }
}

void resetNextBuffer()
{
  int i;
  for (i = 0; i < NUM_PIXELS; i++)
  {
    nextBuffer[i] = 0;
  }
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
      if (bufferAges[i] != MAX_AGE) {
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

void caStep(rule_t rule)
{
  int i;

  // for each strip in the pixel, calculate the next step and store it in nextBuffer
  for (i = 0; i < strip.numPixels(); i++) {
    int on = stepForPixel(rule, i);
    nextBuffer[i] = on;
  }
}

boolean stepForPixel(rule_t rule, int i)
{
  /* a pixel is alive in the next step based on the neighbors and itself in
   * the current step
   *
   * the rule represents the situations where a pixel dies, is born, or stays alive.
   * the rule is an 8 bit value, e.g.:   
   *
   *     0b    0     1     0     1     1     0     1     0
   * 
   * each digit is numbered from right to left with a 3-bit integer:
   *
   *          111   110   101   100   011   010   001   000
   *     0b    0     1     0     1     1     0     1     0
   *
   * to figure out if a cell will be alive in the next step:
   *
   *   1. convert the 3-tuple (prev, cur, next) into a 3 bit binary integer:
   *        (0 for off, 1 for on)
   *
   *           prev ----.    cur    ,---- next
   *                    |     |     |
   *                    V     V     V
   *
   *              0b    0     1     1
   *
   *   2. find the column corresponding to that value in the rule:
   *
   *                     found it! ----.
   *                                   |
   *                                   V
   *
   *          111   110   101   100   011   010   001   000
   *     0b    0     1     0     1     1     0     1     0  
   *
   *   3. if the rule says 0, it's off in the next generation!
   *      if the rule says 1, it's on!
   */
  boolean prev = false, cur = false, next = false;
  unsigned int pattern;
  unsigned int mask;

  /*
   * calculate prev, cur, next
   */
  
  // prev
  if (i > 0 && buffer[i - 1]) prev = true;
  else if (WRAP && i == 0 && buffer[strip.numPixels() - 1]) prev = true;

  // cur
  if (buffer[i]) { cur = true; }

  // next
  if (i < strip.numPixels() - 1 && buffer[i + 1]) next = true;
  else if (WRAP && i == strip.numPixels() - 1 && buffer[0]) next = true;
  
  /*
   * calculate the (prev, cur, next) tuple / rule column identifier
   */

  pattern = 0b0;
  if (prev)
    pattern = pattern | 0b100;
  if (cur)
    pattern = pattern | 0b10;
  if (next)
    pattern = pattern | 0b1;

  /*
   * convert this into a mask:
   *
   *  e.g., for 101:
   *
   *          111   110   101   100   011   010   001   000
   *     0b    0     0     1     0     0     0     0     0  
   *
   * next,    bitwise-AND  the mask with the rule:
   *
   *     0b    0     0     1     0     0     0     0     0    mask
   *  &  0b    0     1     1     0     1     0     1     0    rule
   *  ----------------------------------------------------
   *     0b    0     0     1     0     0     0     0     0 
   * 
   * if this is a true value ( != 0b00000000 ), the pixel will be on in
   * the next generation
   */
  mask = 1 << (pattern);

  if (rule & mask)
    return true;
  else
    return false;
}

/************************
 * COLOR FUNCTIONS
 ************************/

color_channel_t red(color_t color)
{
  return (color >>  8) & 0x7f;
}

color_channel_t green(color_t color)
{
  return (color >> 16) & 0x7f;
}

color_channel_t blue(color_t color)
{
  return color         & 0x7f;
}

/*
 * Gradient is done on individual colors and recombined
 */
color_t gradient(color_t color1, color_t color2, int percent)
{
  color_channel_t c1_r = red(color1);
  color_channel_t c1_g = green(color1);
  color_channel_t c1_b = blue(color1);  

  color_channel_t c2_r = red(color2);
  color_channel_t c2_g = green(color2);
  color_channel_t c2_b = blue(color2);  

  color_channel_t delta_r = (c2_r - c1_r) * percent / 100;
  color_channel_t delta_g = (c2_g - c1_g) * percent / 100;
  color_channel_t delta_b = (c2_b - c1_b) * percent / 100;

  return strip.Color(c1_r + delta_r,
                     c1_g + delta_g,
                     c1_b + delta_b);
}

