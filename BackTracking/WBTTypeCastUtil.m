//
//  WBTTypeCastUtil.m
//  Weibo
//
//  Created by Wade Cheng on 8/19/13.
//  Copyright (c) 2013 Sina. All rights reserved.
//

#import "WBTTypeCastUtil.h"
#import "NSString+WBTSimpleMatching.h"
#import "NSObject+WBTAssociatedObject.h"

id wbt_nonnullValue(id value)
{
    if (nil == value) return nil;
    
    if ([value isKindOfClass:NSDictionary.class])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (obj != [NSNull null]) {
                
                obj = wbt_nonnullValue(obj);
                if (nil != obj)
                {
                    [dict setObject:obj forKey:key];
                }
                
            }
        }];
        
        return dict;
    }
    else if ([value isKindOfClass:NSArray.class])
    {
        NSMutableArray *array = [NSMutableArray array];
        [(NSArray *)value enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (obj != [NSNull null]) {
                
                obj = wbt_nonnullValue(obj);
                if (nil != obj)
                {
                    [array addObject:obj];
                }
                
            }
        }];
        return array;
    }
    else if (value != [NSNull null])
    {
        return value;
    }
    
    return nil;
}

NSNumber *wbt_numberOfValue(id value, NSNumber *defaultValue)
{
    NSNumber *returnValue = defaultValue;
    if (![value isKindOfClass:[NSNumber class]])
    {
        if ([value isKindOfClass:NSString.class])
        {
            NSThread *thread = [NSThread currentThread];
            NSNumberFormatter *formatter = [thread wbt_objectWithAssociatedKey:@"TypeCastUtil.NumberFormatter"];
            if (!formatter)
            {
                formatter = [[NSNumberFormatter alloc] init] ;//autorelease];
                [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
                [thread wbt_setObject:formatter forAssociatedKey:@"TypeCastUtil.NumberFormatter" retained:YES];
            }
            
            returnValue = [formatter numberFromString:(NSString *)value];
        }
    }
    else
    {
        returnValue = value;
    }
    
    return returnValue;
}

NSString *wbt_stringOfValue(id value, NSString *defaultValue)
{
    if (![value isKindOfClass:[NSString class]])
    {
        if ([value isKindOfClass:[NSNumber class]])
        {
            return [value stringValue];
        }
        return defaultValue;
    }
    return value;
}

NSArray *wbt_stringArrayOfValue(id value, NSArray *defaultValue)
{
    if (![value isKindOfClass:[NSArray class]])
        return defaultValue;
    
    for (id item in value) {
        if (![item isKindOfClass:[NSString class]])
            return defaultValue;
    }
    return value;
}

NSDictionary *wbt_dictOfValue(id value, NSDictionary *defaultValue)
{
    if ([value isKindOfClass:[NSDictionary class]])
        return value;
    
    return defaultValue;
}

NSArray *wbt_arrayOfValue(id value ,NSArray *defaultValue)
{
    if ([value isKindOfClass:[NSArray class]])
        return value;
    
    return defaultValue;
}

NSMutableArray *wbt_mutableArrayOfValue(id value ,NSMutableArray *defaultValue)
{
    if ([value isKindOfClass:[NSMutableArray class]])
        return value;
    
    return defaultValue;
}

float wbt_floatOfValue(id value, float defaultValue)
{
    if ([value respondsToSelector:@selector(floatValue)])
        return [value floatValue];
    
    return defaultValue;
}

double wbt_doubleOfValue(id value, double defaultValue)
{
    if ([value respondsToSelector:@selector(doubleValue)])
        return [value doubleValue];
    
    return defaultValue;
}

CGAffineTransform wbt_CGAffineTransformOfValue(id value, CGAffineTransform defaultValue)
{
    if ([value isKindOfClass:[NSString class]] && ![NSString wbt_isEmptyString:value])
        return CGAffineTransformFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGAffineTransformValue];
    
    return defaultValue;
}



CGPoint wbt_pointOfValue(id value, CGPoint defaultValue)
{
    if ([value isKindOfClass:[NSString class]] && ![NSString wbt_isEmptyString:value])
        return NSPointFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGPointValue];
    
    return defaultValue;
}

CGSize wbt_sizeOfValue(id value, CGSize defaultValue)
{
    if ([value isKindOfClass:[NSString class]] && ![NSString wbt_isEmptyString:value])
        return NSSizeFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGSizeValue];
    
    return defaultValue;
}

CGRect wbt_rectOfValue(id value, CGRect defaultValue)
{
    if ([value isKindOfClass:[NSString class]] && ![NSString wbt_isEmptyString:value])
        return NSRectFromString(value);
    else if ([value isKindOfClass:[NSValue class]])
        return [value CGRectValue];
    
    return defaultValue;
}

BOOL wbt_boolOfValue(id value, BOOL defaultValue)
{
    if ([value respondsToSelector:@selector(boolValue)])
        return [value boolValue];
	
    return defaultValue;
}

int wbt_intOfValue(id value, int defaultValue)
{
    if ([value respondsToSelector:@selector(intValue)])
        return [value intValue];
    
    return defaultValue;
}

unsigned int wbt_unsignedIntOfValue(id value, unsigned int defaultValue)
{
    if ([value respondsToSelector:@selector(unsignedIntValue)])
        return [value unsignedIntValue];
    
    return defaultValue;
}

long long int wbt_longLongOfValue(id value, long long int defaultValue)
{
    if ([value respondsToSelector:@selector(longLongValue)])
        return [value longLongValue];
    
    return defaultValue;
}

unsigned long long int wbt_unsignedLongLongOfValue(id value, unsigned long long int defaultValue)
{
    if ([value respondsToSelector:@selector(unsignedLongLongValue)])
        return [value unsignedLongLongValue];
    
    return defaultValue;
}

NSInteger wbt_integerOfValue(id value, NSInteger defaultValue)
{
    if ([value respondsToSelector:@selector(integerValue)])
        return [value integerValue];
    
    return defaultValue;
}

NSUInteger wbt_unsignedIntegerOfValue(id value, NSUInteger defaultValue)
{
    if ([value respondsToSelector:@selector(unsignedIntegerValue)])
        return [value unsignedIntegerValue];
    
    return defaultValue;
}

UIImage *wbt_imageOfValue(id value, UIImage *defaultValue)
{
    if ([value isKindOfClass:[UIImage class]])
        return value;
    
    return defaultValue;
}

UIColor *wbt_colorOfValue(id value, UIColor *defaultValue)
{
    if ([value isKindOfClass:[UIColor class]])
        return value;
    
    return defaultValue;
}

time_t wbt_timeOfValue(id value, time_t defaultValue)
{
    NSString *stringTime = wbt_stringOfValue(value, nil);
    
    struct tm created;
    time_t now;
    time(&now);
    
    if (stringTime)
    {
        if (strptime([stringTime UTF8String], "%a %b %d %H:%M:%S %z %Y", &created) == NULL)
        {
            // 为了兼顾 userDefaults 可能传值不正确的情况
            if (strptime([stringTime UTF8String], "%a, %d %b %Y %H:%M:%S %z", &created) == NULL)
            {
                return defaultValue;
            }
        }
        
        return mktime(&created);
    }
    
    return defaultValue;
}

NSDate *wbt_dateOfValue(id value)
{
    if ([value isKindOfClass:[NSNumber class]])
    {
        return [NSDate dateWithTimeIntervalSince1970:[value intValue]];
    }
    else if ([value isKindOfClass:[NSString class]] && [value length] > 0)
    {
        return [NSDate dateWithTimeIntervalSince1970:wbt_timeOfValue(value, [[NSDate date] timeIntervalSince1970])];
    }
    else if ([value isKindOfClass:[NSDate class]])
    {
        return (NSDate *)value;
    }
    
    return nil;
}


NSData *wbt_dataOfValue(id value, NSData *defaultValue)
{
    if ([value isKindOfClass:[NSData class]])
    {
        return value;
    }
    else if ([value isKindOfClass:[NSString class]])
    {
        return [value dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    return defaultValue;
}

NSURL *wbt_urlOfValue(id value, NSURL *defaultValue)
{
    if ([value isKindOfClass:[NSURL class]])
    {
        return value;
    }
    else if ([value isKindOfClass:[NSString class]])
    {
        return [NSURL fileURLWithPath:value];
    }
    else if ([value isKindOfClass:[NSData class]])
    {
        id obj = [NSKeyedUnarchiver unarchiveObjectWithData:value];
        if ([obj isKindOfClass:[NSURL class]]) {
            NSURL *url = (NSURL *)obj;
            
            return url;
        }
    }
    
    return defaultValue;
}
