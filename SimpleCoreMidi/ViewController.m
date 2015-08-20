//
//  ViewController.m
//  SimpleCoreMidi
//
//  Created by Thierry Sansaricq on 8/18/15.
//  Copyright (c) 2015 Thierry Sansaricq. All rights reserved.
//

#import "ViewController.h"


@interface ViewController () <MidiEngineDelegate>

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _midiEngine = [[MidiEngine alloc] init];
    _midiEngine.delegate = self;
    
    if(_midiEngine == nil){
        NSLog(@"Failed to initialize midi engine");
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
