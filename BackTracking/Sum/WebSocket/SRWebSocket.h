//
//   Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>

typedef NS_ENUM(NSInteger, SRReadyState) {
    SR_CONNECTING   = 0,
    SR_OPEN         = 1,
    SR_CLOSING      = 2,
    SR_CLOSED       = 3,
};

typedef enum SRStatusCode : NSInteger {
    // 0–999: Reserved and not used.
    SRStatusCodeNormal = 1000, //表示一个正常的关闭，意味着连接建立的目标已经完成了。
    SRStatusCodeGoingAway = 1001, //表示终端已经“走开”，例如服务器停机了或者在浏览器中离开了这个页面。
    SRStatusCodeProtocolError = 1002,//表示终端由于协议错误中止了连接。
    SRStatusCodeUnhandledType = 1003,//表示终端由于收到了一个不支持的数据类型的数据（如终端只能理解文本数据，但是收到了一个二进制数据）从而关闭连接。
    // 1004 reserved.
    SRStatusNoStatusReceived = 1005,// 是一个保留值并且不能被终端当做一个关闭帧的状态码。这个状态码是为了给上层应用表示当前没有状态码。
    SRStatusCodeAbnormal = 1006,//是一个保留值并且不能被终端当做一个关闭帧的状态码。这个状态码是为了给上层应用表示连接被异常关闭如没有发送或者接受一个关闭帧这种场景的使用而设计的。
    SRStatusCodeInvalidUTF8 = 1007,//表示终端因为收到了类型不连续的消息（如非 UTF-8 编码的文本消息）导致的连接关闭。
    SRStatusCodePolicyViolated = 1008,// 表示终端是因为收到了一个违反政策的消息导致的连接关闭。这是一个通用的状态码，可以在没有什么合适的状态码（如 1003 或者 1009）时或者可能需要隐藏关于政策的具体信息时返回。
    SRStatusCodeMessageTooBig = 1009,//表示终端由于收到了一个太大的消息无法进行处理从而关闭连接。
    SRStatusCodeMissingExtension = 1010,//表示终端（客户端）因为预期与服务端协商一个或者多个扩展，但是服务端在 WebSocket 握手中没有响应这个导致的关闭。需要的扩展清单应该出现在关闭帧的原因（reason）字段中。
    SRStatusCodeInternalError = 1011,//表示服务端因为遇到了一个意外的条件阻止它完成这个请求从而导致连接关闭。
    SRStatusCodeServiceRestart = 1012,// 服务重启
    SRStatusCodeTryAgainLater = 1013,// 重试
    // 1014: Reserved for future use by the WebSocket standard.
    SRStatusCodeTLSHandshake = 1015,//是一个保留值，不能被终端设置到关闭帧的状态码中。这个状态码是用于上层应用来表示连接失败是因为 TLS 握手失败（如服务端证书没有被验证过）导致的关闭的。
    // 1016–1999: Reserved for future use by the WebSocket standard.
    // 2000–2999: Reserved for use by WebSocket extensions.
    // 3000–3999: Available for use by libraries and frameworks. May not be used by applications. Available for registration at the IANA via first-come, first-serve.
    // 4000–4999: Available for use by applications.
} SRStatusCode;

@class SRWebSocket;

extern NSString *const SRWebSocketErrorDomain;
extern NSString *const SRHTTPResponseErrorKey;

#pragma mark - SRWebSocketDelegate

@protocol SRWebSocketDelegate;

#pragma mark - SRWebSocket

@interface SRWebSocket : NSObject <NSStreamDelegate>

@property (nonatomic, weak) id <SRWebSocketDelegate> delegate;

@property (nonatomic, readonly) SRReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;


@property (nonatomic, readonly) CFHTTPMessageRef receivedHTTPHeaders;

// Optional array of cookies (NSHTTPCookie objects) to apply to the connections
@property (nonatomic, readwrite) NSArray * requestCookies;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
- (id)initWithURLRequest:(NSURLRequest *)request;

// Some helper constructors.
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
- (id)initWithURL:(NSURL *)url;

// Delegate queue will be dispatch_main_queue by default.
// You cannot set both OperationQueue and dispatch_queue.
- (void)setDelegateOperationQueue:(NSOperationQueue*) queue;
- (void)setDelegateDispatchQueue:(dispatch_queue_t) queue;

// By default, it will schedule itself on +[NSRunLoop SR_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// SRWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;

- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

// Send a UTF8 String or Data.
- (void)send:(id)data;

// Send Data (can be nil) in a ping message.
- (void)sendPing:(NSData *)data;

@end

#pragma mark - SRWebSocketDelegate

@protocol SRWebSocketDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;

// Return YES to convert messages sent as Text to an NSString. Return NO to skip NSData -> NSString conversion for Text messages. Defaults to YES.
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket;

@end

#pragma mark - NSURLRequest (SRCertificateAdditions)

@interface NSURLRequest (SRCertificateAdditions)

@property (nonatomic, retain, readonly) NSArray *SR_SSLPinnedCertificates;

@end

#pragma mark - NSMutableURLRequest (SRCertificateAdditions)

@interface NSMutableURLRequest (SRCertificateAdditions)

@property (nonatomic, retain) NSArray *SR_SSLPinnedCertificates;

@end

#pragma mark - NSRunLoop (SRWebSocket)

@interface NSRunLoop (SRWebSocket)

+ (NSRunLoop *)SR_networkRunLoop;

@end
