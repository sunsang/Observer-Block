//
//  NSObject+observer.m
//  Runtime-test
//
//  Created by nice on 2018/7/31.
//  Copyright © 2018 NICE. All rights reserved.
//

#define SSKVONotifying @"SSKVONotifying_"
#define SSKVOAssociatedObservers @"SSKVOAssociatedObservers"

#import "NSObject+observer.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation SSObservationInfo


@end

@implementation NSObject (observer)

static NSString *setterForGetter(NSString *key){
    
    // name  --->  setName:
    if (key.length > 0) {
        NSString *firstLetter = [[key substringWithRange:NSMakeRange(0, 1)] uppercaseString];
        NSString *remainLetters = [key substringFromIndex:1];
        NSString *setter = [NSString stringWithFormat:@"set%@%@:",firstLetter,remainLetters];
        
        return setter;
    } else{
        return nil;
    }
}// 3105 1700 7010 0252 716

static NSString * getterForSetter(NSString *setter){
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    // setName: ---->  name
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    
    return key;
}

- (void)SS_addObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(SSObserverBlock)block{
    
    // 检查对象的类有没有实现对应的setter方法，没有就抛出异常
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        @throw @"没有实现对应的setter方法";
    }
    
    // 如果这个类是第一次添加观察者，检查对象isa指向的类是不是一个KVO类。如果不是，新建一个集成原来类的子类，并把isa指针指向这个子类
    Class class = object_getClass(self);
    NSString *className = NSStringFromClass(class);
    
    if (![className hasPrefix:SSKVONotifying]) { // 第一次添加观察者，没有KVO类
        Class KVOClass = [self makeKvoClassWithOriginalClassName:className];
        object_setClass(self, KVOClass); // 将isa指针指向KVO类
        
    }
    // 检查对象的KVO类重写了这个setter方法没有，如果没有，添加重写的setter方法
    
    // 这个方法不能判断KVO有没有重写setter方法，class_getInstanceMethod  也会去搜索父类，所以此处应该用class_copyMethodList
//    Method KVOSetterMethod = class_getInstanceMethod([self class], setterSelector);
//    if (!KVOSetterMethod) {
//        const char *types = method_getTypeEncoding(KVOSetterMethod);
//        IMP setterMethodIMP = class_getMethodImplementation([self class], setterSelector);
//        class_addMethod([self class], setterSelector, setterMethodIMP, types);
//    }
    
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        Class kvoClass = object_getClass(self);
        class_addMethod(kvoClass, setterSelector, (IMP)kvo_setter, types);
    }
    
    // 添加这个观察者
    SSObservationInfo *observerInfo = [[SSObservationInfo alloc] init];
    observerInfo.key = key;
    observerInfo.block = block;
    NSMutableArray *observers = objc_getAssociatedObject(self, SSKVOAssociatedObservers);
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, SSKVOAssociatedObservers, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:observerInfo];
    
}

- (void)SS_removeObserver:(NSObject *)observer forkey:(NSString *)key{
    
    NSMutableArray *observers = objc_getAssociatedObject(self, SSKVOAssociatedObservers);
    SSObservationInfo *observerToRemove;
    for (SSObservationInfo *observer in observers) {
        if ([observer.key isEqualToString:key] && observer.observer == observer) {
            observerToRemove = observer;
            break;
        }
    }
    [observers removeObject:observerToRemove];
}

- (Class)makeKvoClassWithOriginalClassName:(NSString *)originalClazzName
{
    NSString *kvoClazzName = [SSKVONotifying stringByAppendingString:originalClazzName];
    Class clazz = NSClassFromString(kvoClazzName);
    
    if (clazz) {
        return clazz;
    }
    
    // class doesn't exist yet, make it
    Class originalClazz = object_getClass(self);
    Class kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
    
    // grab class method's signature so we can borrow it
    Method clazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, types);
    
    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}

- (BOOL)hasSelector:(SEL)selector{
    unsigned int methodCount = 0;
    Class class = object_getClass(self);
    Method *methodList = class_copyMethodList(class, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}

// 重写class方法
static Class kvo_class(id self, SEL _cmd){
    // 苹果就是在这里返回父类，所以在写KVO时，看不到集成了一个新类，这里也可以返回KVO子类
    return class_getSuperclass(object_getClass(self));
}

static void kvo_setter(id self, SEL _cmd, id newValue){
    
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superClass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    //   调用父类方法 objc_msgSendSuper();  做一个类型转换，不然会报错，从Xcode6开始的
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    objc_msgSendSuperCasted(&superClass, _cmd, newValue);
    
    
    // 取出观察者
    NSMutableArray *observers = objc_getAssociatedObject(self, SSKVOAssociatedObservers);
    
    for (SSObservationInfo *observer in observers) {
        if ([observer.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                observer.block(self, getterName, oldValue, newValue);
            });
        }
    }
}

@end
