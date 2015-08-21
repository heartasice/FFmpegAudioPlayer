//  Created by Eric Che on 8/21/15.
//  Copyright (c) 2015 Eric Che. All rights reserved.
#import "AudioEngine.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "AudioPacketQueue.h"
#import "AudioUtilities.h"
#import <AVFoundation/AVFoundation.h>
@implementation AudioEngine

+ (AudioEngine *)shareManager {
    
    static AudioEngine *sharedInstance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AudioEngine alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}

- (void)playAudio:(NSString *)audioUrl {
    [self stopPlayAudio];
    
    
    
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if ([self initFFmpegAudioStream:audioUrl withTransferWay:kTCP] == NO) {
            NSLog(@"Init ffmpeg failed");
            return;
        }
        
        if (!aPlayer) {
            aPlayer=[[AudioPlayer alloc]initAudio:nil withCodecCtx:pAudioCodeCtx];
        }
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self performSelector:@selector(delayPlay) withObject:nil afterDelay:1.0f];
        });
        
        // Read Packet in another thread
        [self readFFmpegAudioFrameAndDecode];
        
    });
}
- (void)stopPlayAudio {
    
    [self stopFFmpegAudioStream];
    [aPlayer Stop:YES];
    [self destroyFFmpegAudioStream];
    aPlayer = nil;
    isStop = YES;
}
#pragma mark - FFmpeg processing
- (BOOL)initFFmpegAudioStream:(NSString *)filePath withTransferWay:(kNetworkWay)network {
    
    NSString *pAudioInPath;
    AVCodec  *pAudioCodec;
    
    // Parse header
    uint8_t pInput[] = {0x0ff,0x0f9,0x058,0x80,0,0x1f,0xfc};
    tAACADTSHeaderInfo vxADTSHeader={0};
    
    [AudioUtilities parseAACADTSHeader:pInput ToHeader:(tAACADTSHeaderInfo *) &vxADTSHeader];
    
    // Compare the file path
    if (strncmp([filePath UTF8String], "rtsp", 4) == 0) {
        pAudioInPath = filePath;
        isLocalFile = NO;
    } else if (strncmp([filePath UTF8String], "mms:", 4) == 0) {
        pAudioInPath = filePath;
        pAudioInPath = [pAudioInPath stringByReplacingOccurrencesOfString:@"mms:" withString:@"mmsh:"];
        NSLog(@"Audio path %@", pAudioInPath);
        isLocalFile = NO;
    } else if (strncmp([filePath UTF8String], "mmsh:", 4) == 0) {
        pAudioInPath = filePath;
        isLocalFile = NO;
    } else if(strncmp([filePath UTF8String], "http:", 4) == 0){
        pAudioInPath = filePath;
        isLocalFile = NO;
    }else {
        pAudioInPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:filePath];
        isLocalFile = YES;
    }
    
    // Register FFmpeg
    avcodec_register_all();
    av_register_all();
    if (isLocalFile == NO) {
        avformat_network_init();
    }
    
    @synchronized(self) {
        pFormatCtx = avformat_alloc_context();
    }
    
    // Set network path
    switch (network) {
        case kTCP:
        {
            AVDictionary *option = 0;
            av_dict_set(&option, "rtsp_transport", "tcp", 0);
            // Open video file
            if (avformat_open_input(&pFormatCtx, [pAudioInPath cStringUsingEncoding:NSASCIIStringEncoding], NULL, &option) != 0) {
                NSLog(@"Could not open connection  xxxxx");
                return NO;
            }
            av_dict_free(&option);
        }
            break;
        case kUDP:
        {
            if (avformat_open_input(&pFormatCtx, [pAudioInPath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL) != 0) {
                NSLog(@"Could not open connection");
                return NO;
            }
        }
            break;
    }
    
    pAudioInPath = nil;
    
    // Retrieve stream information
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"Could not find streaming information");
        return NO;
    }
    
    // Dump Streaming information
    av_dump_format(pFormatCtx, 0, [pAudioInPath UTF8String], 0);
    
    // Find the first audio stream
    if ((audioStream = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &pAudioCodec, 0)) <0) {
        NSLog(@"Could not find a audio streaming information");
        return NO;
    } else {
        // Succeed to get streaming information
        NSLog(@"== Audio pCodec Information");
        NSLog(@"name = %s",pAudioCodec->name);
        NSLog(@"sample_fmts = %d",*(pAudioCodec->sample_fmts));
        NSLog(@"package size is %u",pFormatCtx->packet_size);
        if (pAudioCodec->profiles) {
            //            NSLog(@"Profile names = %@", pAudioCodec->profiles);
        } else {
            NSLog(@"Profile is Null");
        }
        
        // Get a pointer to the codec context for the video stream
        pAudioCodeCtx = pFormatCtx->streams[audioStream]->codec;
        
        // Find out the decoder
        pAudioCodec = avcodec_find_decoder(pAudioCodeCtx->codec_id);
        
        // Open codec
        if (avcodec_open2(pAudioCodeCtx, pAudioCodec, NULL) < 0) {
            return NO;
        }
    }
    
    isStop = NO;
    
    return YES;
}

- (void)readFFmpegAudioFrameAndDecode
{
    int error;
    AVPacket aPacket;
    av_init_packet(&aPacket);
    
    if (isLocalFile) {
        // Local File playing
        while (isStop == NO) {
            // Read frame
            error = av_read_frame(pFormatCtx, &aPacket);
            if (error == AVERROR_EOF) {
                // End of playing music
                isStop = YES;
            } else if (error == 0) {
                // During playing..
                if (aPacket.stream_index == audioStream) {
                    if ([aPlayer putAVPacket:&aPacket] <=0 ) {
                        NSLog(@"Put Audio packet error");
                    }
                    // For local file, packet should delay
                    usleep(1000 * 25);
                } else {
                    av_free_packet(&aPacket);
                }
            } else {
                // Error occurs
                NSLog(@"av_read_frame error :%s", av_err2str(error));
                isStop = YES;
            }
        }
    } else {
        
        // Remote File playing
        while (isStop == NO) {
            // Read frame
            error = av_read_frame(pFormatCtx, &aPacket);
            if (error == AVERROR_EOF) {
                // End of playing music
                isStop = YES;
            } else if (error == 0) {
                // During playing..
                if (aPacket.stream_index == audioStream) {
                    if ([aPlayer putAVPacket:&aPacket] <=0 ) {
                        NSLog(@"Put Audio packet error");
                    }
                } else {
                    av_free_packet(&aPacket);
                }
            } else {
                // Error occurs
                NSLog(@"av_read_frame error :%s", av_err2str(error));
                isStop = YES;
            }
        }
    }
    
    NSLog(@"End of playing ffmpeg");
    //    av_free(pFormatCtx);
    //    pFormatCtx=NULL;
    [self performSelectorOnMainThread:@selector(mainThread) withObject:nil waitUntilDone:YES];
}

- (void)stopFFmpegAudioStream
{
    isStop = YES;
}
- (void)destroyFFmpegAudioStream
{
    avformat_network_deinit();
}

- (void)delayPlay {
    
    if (isStop) return ;
    
    if (([aPlayer getStatus] != eAudioRunning) && aPlayer) {
        [aPlayer Play];
    }
}

- (void)mainThread {
    // do nothing...
}

@end
