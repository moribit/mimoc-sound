#include "../tests/reference/tone_waveform.hpp"
#include "../integration/tone_studio_renderer.h"
#include <cstdio>
int main(){FILE *legacy=fopen(".zig-cache/legacy.pcm","wb");FILE *portable=fopen(".zig-cache/portable.pcm","wb");if(!legacy||!portable)return 1;tone_engine e;tone_init(&e,tone_baseline());tone_key(&e,1);float phase=0;
 for(unsigned i=0;i<44100;i++){if(i==22050)tone_key(&e,0);int16_t a=audio::tone::to_pcm(audio::tone::soft_sample(phase)*.24f*audio::tone::one_shot_gain(i,22050,44100));int16_t b=tone_next(&e);fwrite(&a,2,1,legacy);fwrite(&b,2,1,portable);phase+=audio::tone::kTwoPi*450/44100;if(phase>=audio::tone::kTwoPi)phase-=audio::tone::kTwoPi;}
 fclose(legacy);fclose(portable);return 0;}
