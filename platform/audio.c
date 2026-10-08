#include <AudioUnit/AudioUnit.h>
#include <stdatomic.h>
#include <mach/mach_time.h>
static AudioUnit unit;
static double ticks_per_second;
static uint64_t previous;
static double previous_duration;
extern void tone_audio_render(float *, unsigned, int);
static OSStatus render(void *ref, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *data) {
 (void)ref;(void)flags;(void)time;(void)bus;
 uint64_t now=mach_absolute_time();
 int late=previous && (now-previous)/ticks_per_second > previous_duration*1.5;
 previous=now; previous_duration=frames/44100.0;
 if(data->mNumberBuffers!=1 || data->mBuffers[0].mDataByteSize<frames*sizeof(float))return kAudio_ParamError;
 tone_audio_render(data->mBuffers[0].mData,frames,late); return noErr;
}
void tone_audio_close(void) {if(unit){AudioOutputUnitStop(unit);AudioUnitUninitialize(unit);AudioComponentInstanceDispose(unit);unit=NULL;}previous=0;}
int tone_audio_open(void) {
 mach_timebase_info_data_t info; mach_timebase_info(&info);ticks_per_second=1e9*info.denom/info.numer;
 AudioComponentDescription desc={kAudioUnitType_Output,kAudioUnitSubType_DefaultOutput,kAudioUnitManufacturer_Apple,0,0};
 AudioComponent component=AudioComponentFindNext(NULL,&desc); if(!component)return -1;
 OSStatus status=AudioComponentInstanceNew(component,&unit);if(status)return status;
 AudioStreamBasicDescription format={44100,kAudioFormatLinearPCM,kAudioFormatFlagsNativeFloatPacked,4,1,4,1,32,0};
 status=AudioUnitSetProperty(unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,0,&format,sizeof(format));
 AURenderCallbackStruct callback={render,NULL};
 if(!status)status=AudioUnitSetProperty(unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&callback,sizeof(callback));
 if(!status)status=AudioUnitInitialize(unit);if(!status)status=AudioOutputUnitStart(unit);
 if(status)tone_audio_close();return status;
}
