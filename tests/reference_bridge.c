#include "../integration/tone_studio_renderer.h"
static tone_engine engine;
void reference_init(void){tone_init(&engine,tone_baseline());}
void reference_key(int down){tone_key(&engine,down);}
void reference_update(float hz,float harmonic){engine.target.frequency_hz=hz;engine.target.harmonic_2=harmonic;}
int16_t reference_next(void){return tone_next(&engine);}
