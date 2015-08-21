//  Created by Eric Che on 8/21/15.
//  Copyright (c) 2015 Eric Che. All rights reserved.

#import <Foundation/Foundation.h>
#include "libavformat/avformat.h"

@interface AudioPacketQueue : NSObject{
    NSMutableArray *pQueue;
    NSLock *pLock;

}
@property  (nonatomic)  NSInteger count;
@property  (nonatomic)  NSInteger size;
- (id) initQueue;
- (void) destroyQueue;
-(int) putAVPacket: (AVPacket *) pkt;
-(int) getAVPacket :(AVPacket *) pkt;
-(void)freeAVPacket:(AVPacket *) pkt;
@end
