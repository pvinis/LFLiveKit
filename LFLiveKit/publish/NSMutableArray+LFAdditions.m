//
//  NSMutableArray+LFAdditions.m
//  YYKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "NSMutableArray+LFAdditions.h"

@implementation NSMutableArray (LFAdditions)

- (id)popFirstObject {
    id obj = nil;
    if (self.count > 0) {
        obj = self.firstObject;
		[self removeObjectAtIndex:0];
    }
    return obj;
}

@end
