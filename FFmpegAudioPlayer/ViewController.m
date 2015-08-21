//
//  ViewController.m
//  FFmpegAudioPlayer
//
//  Created by Eric Che on 8/21/15.
//  Copyright (c) 2015 Eric Che. All rights reserved.
//

#import "ViewController.h"
#import "AudioEngine.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AudioEngine shareManager]playAudio:@"http://183.251.82.238:5011/vod/hls/005.m3u8"];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
