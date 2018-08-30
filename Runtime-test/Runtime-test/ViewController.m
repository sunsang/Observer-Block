//
//  ViewController.m
//  Runtime-test
//
//  Created by nice on 2018/7/27.
//  Copyright © 2018 NICE. All rights reserved.
//

#import "ViewController.h"
#import <libkern/OSAtomic.h>
#import <Pthread.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    [self testBlockObserve];
}

- (void)test{
    
    dispatch_semaphore_t signal = dispatch_semaphore_create(1);
    dispatch_time_t timeOut = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_semaphore_wait(signal, timeOut);
        sleep(2);
        NSLog(@"操作1");
        dispatch_semaphore_signal(signal);
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_semaphore_wait(signal, timeOut);
        sleep(1);
        NSLog(@"操作2");
        dispatch_semaphore_signal(signal);
    });
    
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
    
    pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, &attr);
    
    
    pthread_mutexattr_t mutext = PTHREAD_MUTEX_INITIALIZER;
    
    @synchronized (self) {
        
    }
}


- (void)testBlockObserve{
    
    
}

@end
