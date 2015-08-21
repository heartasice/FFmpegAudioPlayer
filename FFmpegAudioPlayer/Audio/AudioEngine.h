//  Created by Eric Che on 8/21/15.
//  Copyright (c) 2015 Eric Che. All rights reserved.
#import <Foundation/Foundation.h>
#import "AudioPlayer.h"

typedef enum {
    kTCP = 0,
    kUDP
}kNetworkWay;

@interface AudioEngine : NSObject {
 @private
    AVFormatContext *pFormatCtx;
    AVCodecContext *pAudioCodeCtx;
    
    int    audioStream;
    
    AudioPlayer *aPlayer;
    BOOL  isStop;
    BOOL  isLocalFile;
}
+ (AudioEngine *)shareManager;
- (void)playAudio:(NSString *)audioUrl;
- (void)stopPlayAudio;
- (BOOL)initFFmpegAudioStream:(NSString *)filePath withTransferWay:(kNetworkWay)network;
- (void)readFFmpegAudioFrameAndDecode;
- (void)stopFFmpegAudioStream;
- (void)destroyFFmpegAudioStream;

- (void)delayPlay;

- (void)mainThread;


@end
