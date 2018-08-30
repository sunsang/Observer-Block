//
//  NSObject+observer.h
//  Runtime-test
//
//  Created by nice on 2018/7/31.
//  Copyright © 2018 NICE. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SSObserverBlock)(id observerObject,NSString *observerKey, id oldValue, id newValue);

@interface SSObservationInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) SSObserverBlock block;

@end

@interface NSObject (observer)


- (void)SS_addObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(SSObserverBlock)block;

- (void)SS_removeObserver:(NSObject *)observer forkey:(NSString *)key;

@end

