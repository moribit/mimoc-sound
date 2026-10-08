#include "baseline.h"
int main(void){tone_engine engine;tone_init(&engine,tone_studio_exported_parameters());tone_key(&engine,1);int peak=0;for(int i=0;i<44100;i++){int v=tone_next(&engine);if(v<0)v=-v;if(v>peak)peak=v;}return peak>0&&peak<32767?0:1;}
