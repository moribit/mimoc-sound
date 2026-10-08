#pragma once
/* Portable C99 reference for method A. No RTOS, device, allocation or I/O. */
#include <math.h>
#include <stdint.h>
#include <string.h>
typedef struct {float frequency_hz,harmonic_2,harmonic_3,attack_ms,release_ms,gain;int triangle;} tone_parameters;
typedef struct {tone_parameters current,target;float rate,phase,mix,envelope,from,goal;uint32_t position,length;int down;} tone_engine;
static inline float tone_clamp(float x,float lo,float hi){return fminf(hi,fmaxf(lo,x));}
static inline tone_parameters tone_baseline(void){tone_parameters p={450,.025f,0,3,4,.24f,0};return p;}
static inline void tone_init(tone_engine *e,tone_parameters p){memset(e,0,sizeof(*e));e->current=e->target=p;e->rate=44100;e->length=2;e->mix=p.triangle?1:0;}
static inline void tone_key(tone_engine *e,int down){if(e->down==down)return;e->down=down;e->from=e->envelope;e->goal=down?1:0;e->position=0;e->length=(uint32_t)(e->rate*fmaxf(1,down?e->target.attack_ms:e->target.release_ms)/1000);if(e->length<2)e->length=2;}
static inline int16_t tone_next(tone_engine *e){
 const float alpha=1-expf(-1/(.005f*e->rate));
 #define TONE_SMOOTH(field) e->current.field+=alpha*(e->target.field-e->current.field)
 TONE_SMOOTH(frequency_hz);TONE_SMOOTH(harmonic_2);TONE_SMOOTH(harmonic_3);TONE_SMOOTH(gain);
 #undef TONE_SMOOTH
 e->mix+=alpha*((e->target.triangle?1.f:0.f)-e->mix);
 if(e->position<e->length){float t=(float)e->position/(e->length-1);e->envelope=e->from+(e->goal-e->from)*t*t*(3-2*t);e->position++;}else e->envelope=e->goal;
 const float tau=6.283185307179586f;const tone_parameters p=e->current;
 float sine=sinf(e->phase);float triangle=1-4*fabsf(e->phase/tau-.5f);
 float wave=(sine+e->mix*(triangle-sine)+p.harmonic_2*sinf(2*e->phase)+p.harmonic_3*sinf(3*e->phase))/(1+p.harmonic_2+p.harmonic_3);
 float sample=wave*p.gain*e->envelope;e->phase+=tau*p.frequency_hz/e->rate;if(e->phase>=tau)e->phase-=tau;
 return (int16_t)(tone_clamp(sample,-1,1)*32767);
}
