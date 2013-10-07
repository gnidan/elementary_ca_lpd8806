#ifndef __LPD8806_H__
#define __LPD8806_H__

typedef uint32_t color_t;
typedef uint8_t rule_t;
typedef uint8_t color_channel_t;

/**********************
 * MAIN FUNCTIONS
 *********************/
void fillBufferRandomly();
void resetBuffer();
void resetNextBuffer();
void resetBufferAges();
void updateBuffer();

/**********************
 * CA FUNCTIONS
 *********************/

void caStep(rule_t rule);
boolean stepForPixel(rule_t rule, int i);

/************************
 * COLOR FUNCTIONS
 ************************/

color_channel_t red(color_t color);
color_channel_t green(color_t color);
color_channel_t blue(color_t color);
color_t gradient(color_t color1, color_t color2, int percent);

#endif
