#import <AppKit/AppKit.h>
#include <string.h>
int tone_prompt(const char *title,char *buffer,size_t capacity){
 NSAlert *alert=[NSAlert new];alert.messageText=[NSString stringWithUTF8String:title];[alert addButtonWithTitle:@"OK"];[alert addButtonWithTitle:@"Cancel"];
 NSTextField *field=[[NSTextField alloc]initWithFrame:NSMakeRect(0,0,320,24)];alert.accessoryView=field;[alert.window setInitialFirstResponder:field];
 if([alert runModal]!=NSAlertFirstButtonReturn)return -1;const char *s=field.stringValue.UTF8String;size_t len=strlen(s);if(len>=capacity)return -1;memcpy(buffer,s,len+1);return (int)len;
}
int tone_file_path(int save,const char *extension,char *buffer,size_t capacity){
 NSSavePanel *panel=save?[NSSavePanel savePanel]:[NSOpenPanel openPanel];panel.allowedFileTypes=@[[NSString stringWithUTF8String:extension]];
 if([panel runModal]!=NSModalResponseOK)return 0;const char *path=panel.URL.path.UTF8String;if(strlen(path)>=capacity)return 0;strcpy(buffer,path);return 1;
}
