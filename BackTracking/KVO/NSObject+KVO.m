//
//  NSObject+KVO.m
//  BackTracking
//
//  Created by ZhuLuxi on 2020/7/1.
//  Copyright © 2020 newboy. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/message.h>
static const char KVOArrayKey;

@interface WTKVOItem: NSObject

@property (nonatomic, weak) id obj;

@property (nonatomic, strong) NSString *keyPath;


@end

@implementation WTKVOItem


@end

@implementation NSObject (KVO)
+ (void)load
{
    Method addObserver = class_getInstanceMethod(self, @selector(addObserver:forKeyPath:options:context:));
    Method wt_addObserver = class_getInstanceMethod(self, @selector(wt_addObserver:forKeyPath:options:context:));
    method_exchangeImplementations(addObserver, wt_addObserver);

    Method removeObserver = class_getInstanceMethod(self, @selector(removeObserver:forKeyPath:));
    Method wt_removeObserver = class_getInstanceMethod(self, @selector(wt_removeObserver:forKeyPath:));
    method_exchangeImplementations(removeObserver, wt_removeObserver);
    
    //hook dealloc
    Method originalDealloc = class_getInstanceMethod(self, NSSelectorFromString(@"dealloc"));
    Method newDealloc = class_getInstanceMethod(self, @selector(autoRemoveObserverDealloc));
    method_exchangeImplementations(originalDealloc, newDealloc);
    
}

- (void)autoRemoveObserverDealloc
{
   NSLog(@"autoRemoveObserverDealloc----");
//    NSMutableDictionary *keyPaths = objc_getAssociatedObject(self, &KVOArrayKey);
//    if (keyPaths == nil) return;
//    NSLog(@"111111111-----%@",keyPaths);
//    [keyPaths enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, WTKVOItem * _Nonnull obj, BOOL * _Nonnull stop) {
//        [obj.obj removeObserver: self forKeyPath: obj.keyPath];
//    }];
//    objc_setAssociatedObject(self, &KVOArrayKey, NULL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//
//    // 下面这句相当于直接调用dealloc
//       [self autoRemoveObserverDealloc];
}

- (void)wt_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    if (observer == nil || keyPath == nil || keyPath.length == 0) return;
    
    NSMutableDictionary *keyPathdict = objc_getAssociatedObject(observer, &KVOArrayKey);
    if (keyPathdict == nil)
    {
        keyPathdict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(observer, &KVOArrayKey, keyPathdict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    WTKVOItem *item = [WTKVOItem new];
    item.keyPath = keyPath;
    item.obj = self;
    
    keyPathdict[keyPath] = item;

    [self wt_addObserver: observer forKeyPath: keyPath options: options context: context];
    
    
//    [self replaceImpl: observer.class];
}

- (void)wt_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    NSMutableDictionary *keyPaths = objc_getAssociatedObject(observer, &KVOArrayKey);
    if (keyPaths == nil) return;
    
    if ([keyPaths objectForKey: keyPath])
    {
        [self wt_removeObserver: observer forKeyPath: keyPath];
        
        [keyPaths removeObjectForKey: keyPath];
    }
}

- (void)wt_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    NSMutableDictionary *keyPaths = objc_getAssociatedObject(observer, &KVOArrayKey);
    if (keyPaths == nil) return;
    
    if ([keyPaths objectForKey: keyPath])
    {
        [self wt_removeObserver: observer forKeyPath: keyPath context: context];
        
        [keyPaths removeObjectForKey: keyPath];
    }
}

- (void)replaceImpl:(Class)cls
{
    NSLog(@"replaceImpl");
    Method dealloc = class_getInstanceMethod([self class], NSSelectorFromString(@"dealloc"));
    
    __block IMP deallocIMP = method_setImplementation(dealloc, imp_implementationWithBlock(^(__unsafe_unretained id self){
        
       ((void(*)(id, SEL))objc_msgSend)(self, @selector(cleanupSEL));
        ((void(*)(id, SEL))deallocIMP)(self, NSSelectorFromString(@"dealloc"));
    
    }));
}

- (void)cleanupSEL
{
    NSLog(@"cleanupSEL");
    NSMutableDictionary *keyPaths = objc_getAssociatedObject(self, &KVOArrayKey);
    if (keyPaths == nil) return;
    
    [keyPaths enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, WTKVOItem * _Nonnull obj, BOOL * _Nonnull stop) {
        
        [obj.obj removeObserver: self forKeyPath: obj.keyPath];
        
    }];
    
    
    objc_setAssociatedObject(self, &KVOArrayKey, NULL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end
