//
//  WAMIBridge.h
//
//  Created by Jeremy Olmsted-Thompson on 2/12/13.
//  Copyright (c) 2013 Jeremy Olmsted-Thompson. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ResponseBlock)(id response);
typedef void (^ErrorBlock)(id response);
typedef void (^RevertBlock)();
typedef void (^WAMIBlock)(id parameters, ResponseBlock responseBlock, ErrorBlock errorBlock, RevertBlock revertBlock);

@interface NSJSONSerialization (WAMIJSONString)

+(NSString*)stringWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
+(id)JSONObjectWithString:(NSString *)string options:(NSJSONReadingOptions)opt error:(NSError *__autoreleasing *)error;

@end

@interface UIWebView (WAMI)

-(NSString*)stringByEvaluatingJavaScriptFunction:(NSString*)functionName withArguments:(NSArray*)orderedArguments;
-(id)objectByEvaluatingJavaScriptFunction:(NSString*)functionName withArguments:(NSArray*)orderedArguments;

@end

@interface WAMIBridge : NSObject <UIWebViewDelegate>

@property (nonatomic, assign) id<UIWebViewDelegate> delegate;

-(void)setMethod:(NSString*)name block:(WAMIBlock)block;
-(void)setConsoleHandler:(void (^)(NSString *logType, NSArray *parameters))consoleHandler;

@end
