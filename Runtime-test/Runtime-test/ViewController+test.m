//
//  ViewController+test.m
//  Runtime-test
//
//  Created by nice on 2018/7/31.
//  Copyright © 2018 NICE. All rights reserved.
//

#import "ViewController+test.h"
#import <objc/runtime.h>

@implementation ViewController (test)


- (void)setName:(NSString *)name{
    objc_setAssociatedObject(self.name, _cmd, name, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)name{
    return objc_getAssociatedObject(self.name, @selector(setName:));
}


@end
