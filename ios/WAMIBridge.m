//
//  WAMIBridge.m
//
//  Created by Jeremy Olmsted-Thompson on 2/12/13.
//  Copyright (c) 2013 Jeremy Olmsted-Thompson. All rights reserved.
//

#import "WAMIBridge.h"

@interface WAMIBridge ()

@property (nonatomic, strong) NSMutableDictionary *registeredBlocks;
@property (nonatomic, copy) void (^consoleHandler)(NSString* logType, NSArray* parameters);

@end

@implementation WAMIBridge

-(id)init {
    if ((self = [super init])) {
        self.registeredBlocks = [NSMutableDictionary dictionary];
        __block WAMIBridge *this = self;
        [self setMethod:@"console" block:^(id parameters, ResponseBlock responseBlock, ErrorBlock errorBlock, RevertBlock revertBlock) {
            if (this.consoleHandler) {
                this.consoleHandler(parameters[0], [parameters subarrayWithRange:NSMakeRange(1, [parameters count] - 1)]);
            }
        }];
    }
    return self;
}

-(void)dealloc {
    self.registeredBlocks = nil;
    self.consoleHandler = nil;
}

-(void)setMethod:(NSString*)name block:(WAMIBlock)block {
    [_registeredBlocks setObject:[block copy] forKey:name];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.scheme isEqualToString:@"wami"]) {
        NSDictionary *methodData = [NSJSONSerialization JSONObjectWithString:[[[request.URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding] substringFromIndex:7] options:0 error:nil];
        NSString *callID = methodData[@"callID"];
        if (!_registeredBlocks[methodData[@"method"]]) {
            if ([methodData[@"expectsResponse"] boolValue]) {
                [webView stringByEvaluatingJavaScriptFunction:@"WAMI.revertAppMethod" withArguments:@[methodData[@"method"], callID, methodData[@"parameters"]]];
            }
            return NO;
        }
        @try {
            ((WAMIBlock)_registeredBlocks[methodData[@"method"]])(methodData[@"parameters"], ^(id response){
                [webView stringByEvaluatingJavaScriptFunction:@"WAMI.finishAppMethod" withArguments:@[callID, response]];
            }, ^(id response){
                [webView stringByEvaluatingJavaScriptFunction:@"WAMI.failAppMethod" withArguments:@[callID, response]];
            }, ^{
                [webView stringByEvaluatingJavaScriptFunction:@"WAMI.revertAppMethod" withArguments:@[methodData[@"method"], callID, methodData[@"parameters"]]];
            });
        } @catch (NSException *exception) {
            NSLog(@"Exception in WAMI Method %@ - %@: %@\n%@", methodData[@"method"], methodData[@"callID"], exception, [exception callStackSymbols]);
        }
        return NO;
    } else {
        if ([_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
            return [_delegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
        } else {
            return YES;
        }
    }
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if ([_delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [_delegate webView:webView didFailLoadWithError:error];
    }
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    //shouldStartLoadWithRequest is not called until after this method returns so don't trigger "platformChanged" event until it does.
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:@"WAMI.setCurrentPlatform(\"iOS\");"];
        NSLog(@"WAMI: %@", [webView stringByEvaluatingJavaScriptFromString:@"WAMI.platform"]);
    });
    if ([_delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [_delegate webViewDidFinishLoad:webView];
    }
}

-(void)webViewDidStartLoad:(UIWebView *)webView {
    if ([_delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [_delegate webViewDidStartLoad:webView];
    }
}

@end

@implementation NSJSONSerialization (WAMIJSONString)

+(NSString*)stringWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:opt error:error] encoding:NSUTF8StringEncoding];
}

+(id)JSONObjectWithString:(NSString *)string options:(NSJSONReadingOptions)opt error:(NSError *__autoreleasing *)error {
    return [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:opt error:error];
}

@end

@implementation UIWebView (WAMI)

-(NSString*)stringByEvaluatingJavaScriptFunction:(NSString*)functionName withArguments:(NSArray*)orderedArguments {
    NSString *jsonArray = [NSJSONSerialization stringWithJSONObject:orderedArguments options:0 error:nil];
    NSString *args = [jsonArray substringWithRange:NSMakeRange(1, [jsonArray length] - 2)];
    return [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@(%@)", functionName, args]];
}

-(id)objectByEvaluatingJavaScriptFunction:(NSString*)functionName withArguments:(NSArray*)orderedArguments {
    NSString *jsonArray = [NSJSONSerialization stringWithJSONObject:orderedArguments options:0 error:nil];
    NSString *args = [jsonArray substringWithRange:NSMakeRange(1, [jsonArray length] - 2)];
    return [NSJSONSerialization JSONObjectWithString:[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSON.stringify(%@(%@))", functionName, args]] options:NSJSONReadingAllowFragments error:nil];
}

@end
