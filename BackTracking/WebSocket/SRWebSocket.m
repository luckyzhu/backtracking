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


#import "SRWebSocket.h"

#if TARGET_OS_IPHONE
#define HAS_ICU
#endif

#ifdef HAS_ICU
#import <unicode/utf8.h>
#endif

#if TARGET_OS_IPHONE
#import <Endian.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import <CommonCrypto/CommonDigest.h>
#import <Security/SecRandom.h>

/*
 sr_dispatch_retain
 sr_dispatch_release
 写宏的目的:sdk6.0以后GCD对象可以有arc处理。不需要手动retain和release。dk6.0以前不管arc或者none-arc都需要手动retain和release GCD 对象。
 */
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#define sr_dispatch_retain(x)
#define sr_dispatch_release(x)
#define maybe_bridge(x) ((__bridge void *) x)
#else
#define sr_dispatch_retain(x) dispatch_retain(x)
#define sr_dispatch_release(x) dispatch_release(x)
#define maybe_bridge(x) (x)
#endif

#if !__has_feature(objc_arc) 
#error SocketRocket must be compiled with ARC enabled
#endif

/*
 Opcode: 4 bit
 定义“有效负载数据”的解释。如果收到一个未知的操作码，接收终端必须断开WebSocket连接。下面的值是被定义过的。
 ​ %x0 表示一个持续帧
 ​ %x1 表示一个文本帧
 ​ %x2 表示一个二进制帧
 ​ %x3-7 预留给以后的非控制帧
 ​ %x8 表示一个连接关闭包
 ​ %x9 表示一个ping包
 ​ %xA 表示一个pong包
 ​ %xB-F 预留给以后的控制帧
 */
typedef enum  {
    SROpCodeTextFrame = 0x1,//数据帧
    SROpCodeBinaryFrame = 0x2,//数据帧
    // 3-7 reserved.
    SROpCodeConnectionClose = 0x8, //控制帧
    SROpCodePing = 0x9,//控制帧
    SROpCodePong = 0xA,//控制帧
    // B-F reserved.
} SROpCode;

//数据帧的帧头，总共是2个字节
typedef struct {
    BOOL fin; //等于1. 表示这是消息的最后一个片段。第一个片段也有可能是最后一个片段。
//  BOOL rsv1;
//  BOOL rsv2;
//  BOOL rsv3;
    uint8_t opcode;
    BOOL masked; //从客户端发送到服务端的帧都需要设置这个bit位为1
    uint64_t payload_length; //Payload length: 7 bits, 7+16 bits, or 7+64 bits
} frame_header;

//服务端这个Accept会用这么一个字符串拼接加密：
/*
 如果客户端收到的Sec-WebSocket-Acceptheader字段或者Sec-WebSocket-Acceptheader字段不等于通过Sec-WebSocket-Key字段的值（作为一个字符串，而不是base64解码后）和"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"串联起来，忽略所有前后空格进行base64 SHA-1编码的值，那么客户端必须关闭连接。
 */
static NSString *const SRWebSocketAppendToSecKeyString = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

static inline int32_t validate_dispatch_data_partial_string(NSData *data);
static inline void SRFastLog(NSString *format, ...);

@interface NSData (SRWebSocket)

- (NSString *)stringBySHA1ThenBase64Encoding;

@end


@interface NSString (SRWebSocket)

- (NSString *)stringBySHA1ThenBase64Encoding;

@end


@interface NSURL (SRWebSocket)

// The origin isn't really applicable for a native application.
// So instead, just map ws -> http and wss -> https.
- (NSString *)SR_origin;

@end


@interface _SRRunLoopThread : NSThread

@property (nonatomic, readonly) NSRunLoop *runLoop;

@end

//base64 SHA-1 算法
static NSString *newSHA1String(const char *bytes, size_t length) {
    uint8_t md[CC_SHA1_DIGEST_LENGTH];

    assert(length >= 0);
    assert(length <= UINT32_MAX);
    CC_SHA1(bytes, (CC_LONG)length, md);
    
    NSData *data = [NSData dataWithBytes:md length:CC_SHA1_DIGEST_LENGTH];
    
    if ([data respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        return [data base64EncodedStringWithOptions:0];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
}

@implementation NSData (SRWebSocket)

- (NSString *)stringBySHA1ThenBase64Encoding;
{
    return newSHA1String(self.bytes, self.length);
}

@end


@implementation NSString (SRWebSocket)

- (NSString *)stringBySHA1ThenBase64Encoding;
{
    return newSHA1String(self.UTF8String, self.length);
}

@end

NSString *const SRWebSocketErrorDomain = @"SRWebSocketErrorDomain";
NSString *const SRHTTPResponseErrorKey = @"HTTPResponseStatusCode";

// Returns number of bytes consumed. Returning 0 means you didn't match.
// Sends bytes to callback handler;
typedef size_t (^stream_scanner)(NSData *collected_data);

typedef void (^data_callback)(SRWebSocket *webSocket,  NSData *data);

/*
  1>size_t:它是一种“整型”类型，里面保存的是一个整数，就像int、long那样。这种整数用来记录一个大小（size）。size_t的全称应该是size type，就是说“一种用来记录大小的数据类型”。
 2> WebSocket协议中：数据是通过一系列数据帧来进行传输的
    客户端必须在它发送到服务器的所有帧中添加掩码，服务端收到没有添加掩码的数据帧以后，必须立即关闭连接。
    服务端禁止在发送数据帧给客户端时添加掩码。客户端如果收到了一个添加了掩码的帧，必须立即关闭连接。
*/
@interface SRIOConsumer : NSObject {
    stream_scanner _scanner;
    data_callback _handler;
    size_t _bytesNeeded;
    BOOL _readToCurrentFrame;
    BOOL _unmaskBytes;
}
@property (nonatomic, copy, readonly) stream_scanner consumer;
@property (nonatomic, copy, readonly) data_callback handler;
@property (nonatomic, assign) size_t bytesNeeded;
@property (nonatomic, assign, readonly) BOOL readToCurrentFrame;
@property (nonatomic, assign, readonly) BOOL unmaskBytes;

@end

// SRIOConsumerPool相关的操作都同一个队列里,保证线程安全
// This class is not thread-safe, and is expected to always be run on the same queue.
@interface SRIOConsumerPool : NSObject

- (id)initWithBufferCapacity:(NSUInteger)poolSize;

- (SRIOConsumer *)consumerWithScanner:(stream_scanner)scanner handler:(data_callback)handler bytesNeeded:(size_t)bytesNeeded readToCurrentFrame:(BOOL)readToCurrentFrame unmaskBytes:(BOOL)unmaskBytes;
- (void)returnConsumer:(SRIOConsumer *)consumer;

@end

@interface SRWebSocket ()  <NSStreamDelegate>

@property (nonatomic) SRReadyState readyState;

@property (nonatomic) NSOperationQueue *delegateOperationQueue;
@property (nonatomic) dispatch_queue_t delegateDispatchQueue;

// Specifies whether SSL trust chain should NOT be evaluated.
// By default this flag is set to NO, meaning only secure SSL connections are allowed.
// For DEBUG builds this flag is ignored, and SSL connections are allowed regardless
// of the certificate trust configuration
@property (nonatomic, readwrite) BOOL allowsUntrustedSSLCertificates;

@end


@implementation SRWebSocket {
    NSInteger _webSocketVersion;
    
    NSOperationQueue *_delegateOperationQueue;
    dispatch_queue_t _delegateDispatchQueue;
    
    dispatch_queue_t _workQueue;
    NSMutableArray *_consumers;

    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
   
    NSMutableData *_readBuffer;
    NSUInteger _readBufferOffset;
 
    NSMutableData *_outputBuffer;
    NSUInteger _outputBufferOffset;
/*
 数据帧的解释：
 https://github.com/HJava/myBlog/blob/master/WebSocket%20协议%20RFC%20文档/【译】WebSocket协议第五章——数据帧(Data%20Framing).md
 */
    uint8_t _currentFrameOpcode; //有效负载数据
    size_t _currentFrameCount;
    size_t _readOpCount;
    uint32_t _currentStringScanPosition;
    NSMutableData *_currentFrameData;
    
    NSString *_closeReason;
    
    NSString *_secKey;
    NSString *_basicAuthorizationString;
    
    BOOL _pinnedCertFound;
    
    uint8_t _currentReadMaskKey[4];
    size_t _currentReadMaskOffset;

    BOOL _consumerStopped;
    
    BOOL _closeWhenFinishedWriting;
    BOOL _failed;

    /*
 //协议规定：安全（secure）字段存在，客户端必须在连接建立以后、发送握手数据之前进行TLS握手。如果TLS握手失败（比如服务端正数没有验证通过），那么客户端必须断开WebSocket连接。否则，所有后续的在此频道上面的数据通信都必须在加密的通道中传输。
 */
    BOOL _secure;
    NSURLRequest *_urlRequest;

    BOOL _sentClose;
    BOOL _didFail;
    BOOL _cleanupScheduled;
    int _closeCode;
    
    BOOL _isPumping;
    
    NSMutableSet *_scheduledRunloops;
    
    // We use this to retain ourselves.
    __strong SRWebSocket *_selfRetain;
    
    NSArray *_requestedProtocols;
    SRIOConsumerPool *_consumerPool;
}

@synthesize delegate = _delegate;
@synthesize url = _url;
@synthesize readyState = _readyState;
@synthesize protocol = _protocol;

static __strong NSData *CRLFCRLF;

+ (void)initialize;
{
    CRLFCRLF = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
}
/*
 初始化方法：必须传NSURL，根据url构建request
 */
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;
{
    self = [super init];
    if (self) {
        assert(request.URL);
        _url = request.URL;
        _urlRequest = request;
        _allowsUntrustedSSLCertificates = allowsUntrustedSSLCertificates;
        
        _requestedProtocols = [protocols copy];
        
        [self _SR_commonInit];
    }
    
    return self;
}

- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
{
    return [self initWithURLRequest:request protocols:protocols allowsUntrustedSSLCertificates:NO];
}

- (id)initWithURLRequest:(NSURLRequest *)request;
{
    return [self initWithURLRequest:request protocols:nil];
}

- (id)initWithURL:(NSURL *)url;
{
    return [self initWithURL:url protocols:nil];
}

- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];    
    return [self initWithURLRequest:request protocols:protocols];
}

- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols allowsUntrustedSSLCertificates:(BOOL)allowsUntrustedSSLCertificates;
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    return [self initWithURLRequest:request protocols:protocols allowsUntrustedSSLCertificates:allowsUntrustedSSLCertificates];
}

- (void)_SR_commonInit;
{
    NSString *scheme = _url.scheme.lowercaseString;
    // 只支持ws wss http https 四种协议
    assert([scheme isEqualToString:@"ws"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"]);
    
    //wss https 是安全型的协议
    if ([scheme isEqualToString:@"wss"] || [scheme isEqualToString:@"https"]) {
        _secure = YES;
    }
    
    _readyState = SR_CONNECTING;  //Socket状态
    _consumerStopped = YES;
    
    //协议规定：请求头必须包含Sec-WebSocket-Version 且值为13
    _webSocketVersion = 13;
  
    //初始化工作的队列,串行
    _workQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    
    // Going to set a specific on the queue so we can validate we're on the work queue 队列设置一个标识
    dispatch_queue_set_specific(_workQueue, (__bridge void *)self, maybe_bridge(_workQueue), NULL);
    
    _delegateDispatchQueue = dispatch_get_main_queue();
    sr_dispatch_retain(_delegateDispatchQueue);
    
    //读写缓冲区
    /*
     怎么理解buffer?
     Buffer是二进制数据，字符串与Buffer之间存在编码关系
     */
    _readBuffer = [[NSMutableData alloc] init]; //读buffer
    _outputBuffer = [[NSMutableData alloc] init]; // 输出buffer
    
    _currentFrameData = [[NSMutableData alloc] init];//当前数据帧

    _consumers = [[NSMutableArray alloc] init];
    
    _consumerPool = [[SRIOConsumerPool alloc] init];
    
    _scheduledRunloops = [[NSMutableSet alloc] init];//注册的runloop
    
    [self _initializeStreams];
    
    // default handlers
}

- (void)assertOnWorkQueue;
{   // 根据队列标识,判断是否在指定的队列
    assert(dispatch_get_specific((__bridge void *)self) == maybe_bridge(_workQueue));
    
    /*
     _workQueue做的事情:
     1> _pumpWriting : 向服务端发送http报文
     2> 数据的读取
     */
}

- (void)dealloc
{
    _inputStream.delegate = nil;
    _outputStream.delegate = nil;

    [_inputStream close];
    [_outputStream close];
    
    if (_workQueue) {
        sr_dispatch_release(_workQueue);
        _workQueue = NULL;
    }
    
    if (_receivedHTTPHeaders) {
        CFRelease(_receivedHTTPHeaders);
        _receivedHTTPHeaders = NULL;
    }
    
    if (_delegateDispatchQueue) {
        sr_dispatch_release(_delegateDispatchQueue);
        _delegateDispatchQueue = NULL;
    }
}

#ifndef NDEBUG

- (void)setReadyState:(SRReadyState)aReadyState;
{
    assert(aReadyState > _readyState);
    _readyState = aReadyState;
}

#endif

- (void)open;
{
    assert(_url);
    // 协议规定：客户端最多有一条连接可以处于CONNECTING状态。
    NSAssert(_readyState == SR_CONNECTING, @"Cannot call -(void)open on SRWebSocket more than once");

    _selfRetain = self;

    // 如果超过了request的timeoutInterval && 状态是正在连接 抛出错误
    if (_urlRequest.timeoutInterval > 0)
    {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, _urlRequest.timeoutInterval * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (self.readyState == SR_CONNECTING)
                [self _failWithError:[NSError errorWithDomain:@"com.squareup.SocketRocket" code:504 userInfo:@{NSLocalizedDescriptionKey: @"Timeout Connecting to Server"}]];
        });
    }

    [self openConnection];
}

// Calls block on delegate queue
- (void)_performDelegateBlock:(dispatch_block_t)block;
{
    if (_delegateOperationQueue) {
        [_delegateOperationQueue addOperationWithBlock:block];
    } else {
        assert(_delegateDispatchQueue);
        dispatch_async(_delegateDispatchQueue, block);
    }
}

- (void)setDelegateDispatchQueue:(dispatch_queue_t)queue;
{
    if (queue) {
        sr_dispatch_retain(queue);
    }
    
    if (_delegateDispatchQueue) {
        sr_dispatch_release(_delegateDispatchQueue);
    }
    
    _delegateDispatchQueue = queue;
}


/*
检查握手信息:::
WebSocket建立连接前，都会以http请求作为握手的方式，这个方法就是在构造http的请求头。
我们来看看RFC规范的标准客户端请求头：

GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Origin: http://example.com
Sec-WebSocket-Protocol: chat, superchat
Sec-WebSocket-Version: 13

标准的服务端响应头：
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
Sec-WebSocket-Protocol: chat

Sec-WebSocket-Key和Sec-WebSocket-Accept这一对值，前者是我们客户端自己生成一个16字节的随机data，然后经过base64转码后的一个随机字符串。

而后者则是服务端返回回来的，我们需要用一开始的Sec-WebSocket-Key与服务端返回的Sec-WebSocket-Accept进行校验：
*/
- (BOOL)_checkHandshake:(CFHTTPMessageRef)httpMessage;
{
     //是否是允许的header
    NSString *acceptHeader = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(httpMessage, CFSTR("Sec-WebSocket-Accept")));

    //为空则被服务器拒绝
    if (acceptHeader == nil) {
        return NO;
    }
    
    NSString *concattedString = [_secKey stringByAppendingString:SRWebSocketAppendToSecKeyString];
    NSString *expectedAccept = [concattedString stringBySHA1ThenBase64Encoding];
    
     //判断是否相同，相同就握手信息对了
    return [acceptHeader isEqualToString:expectedAccept];
}

//协议规定：一旦客户端的握手请求发送出去，那么客户端必须在发送后续数据前等待服务端的响应。客户端必须通过规定的规则验证服务端的请求：
- (void)_HTTPHeadersDidFinish;
{
    // 这个方法的作用就是：验证服务端的header
    NSInteger responseCode = CFHTTPMessageGetResponseStatusCode(_receivedHTTPHeaders);
    
    if (responseCode >= 400) {
        SRFastLog(@"Request failed with response code %d", responseCode);
        [self _failWithError:[NSError errorWithDomain:SRWebSocketErrorDomain code:2132 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"received bad response code from server %ld", (long)responseCode], SRHTTPResponseErrorKey:@(responseCode)}]];
        return;
    }

    if(![self _checkHandshake:_receivedHTTPHeaders]) {
        [self _failWithError:[NSError errorWithDomain:SRWebSocketErrorDomain code:2133 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Invalid Sec-WebSocket-Accept response"] forKey:NSLocalizedDescriptionKey]]];
        return;
    }
    
    NSString *negotiatedProtocol = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(_receivedHTTPHeaders, CFSTR("Sec-WebSocket-Protocol")));
    if (negotiatedProtocol) {
        // Make sure we requested the protocol
        if ([_requestedProtocols indexOfObject:negotiatedProtocol] == NSNotFound) {
            [self _failWithError:[NSError errorWithDomain:SRWebSocketErrorDomain code:2133 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Server specified Sec-WebSocket-Protocol that wasn't requested"] forKey:NSLocalizedDescriptionKey]]];
            return;
        }
        
        _protocol = negotiatedProtocol;
    }
    
    //如果服务端的响应通过了上述的验证过程，那么WebSocket就已经建立连接了，并且WebSocket的连接状态也到了OPEN状态
    self.readyState = SR_OPEN; // 建立连接
    
    // 建立连接后:服务端或客户端可以通过数据帧进行传输
    if (!_didFail) {
        [self _readFrameNew];
    }

    [self _performDelegateBlock:^{
        if ([self.delegate respondsToSelector:@selector(webSocketDidOpen:)]) {
            [self.delegate webSocketDidOpen:self];
        };
    }];
}

//建立连接成功后,读取服务端的数据
- (void)_readHTTPHeader;
{
    if (_receivedHTTPHeaders == NULL) {
        _receivedHTTPHeaders = CFHTTPMessageCreateEmpty(NULL, NO);
    }
    
    //不停的add consumer去读数据
    [self _readUntilHeaderCompleteWithCallback:^(SRWebSocket *self,  NSData *data) {
        //拼接数据，拼到头部
        CFHTTPMessageAppendBytes(_receivedHTTPHeaders, (const UInt8 *)data.bytes, data.length);
        
        /*
         服务端返回的header:
         Connection = Upgrade;
         "Sec-WebSocket-Accept" = "Tpm/3GItxWjlwAy64MdYrJTfyVY=";
         Upgrade = websocket;
         */
         //判断是否接受完
        if (CFHTTPMessageIsHeaderComplete(_receivedHTTPHeaders)) {
            SRFastLog(@"Finished reading headers %@", CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(_receivedHTTPHeaders)));
            [self _HTTPHeadersDidFinish];
        } else {
            //没读完递归调
            [self _readHTTPHeader];
        }
    }];
}

- (void)didConnect;
{//流打开成功后的操作，开始发送http请求建立连接
    SRFastLog(@"Connected");
    //创建一个http request  url
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), (__bridge CFURLRef)_url, kCFHTTPVersion1_1);
    
    // Set host first so it defaults
    //设置head, host:  url+port
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Host"), (__bridge CFStringRef)(_url.port ? [NSString stringWithFormat:@"%@:%@", _url.host, _url.port] : _url.host));
     //密钥数据（生成对称密钥）
    NSMutableData *keyBytes = [[NSMutableData alloc] initWithLength:16];
    //生成随机密钥
    SecRandomCopyBytes(kSecRandomDefault, keyBytes.length, keyBytes.mutableBytes);
    
    //根据版本用base64转码
    if ([keyBytes respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        _secKey = [keyBytes base64EncodedStringWithOptions:0];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _secKey = [keyBytes base64Encoding];
#pragma clang diagnostic pop
    }
    
    assert([_secKey length] == 24);

    // Apply cookies if any have been provided
    //提供cookies
    NSDictionary * cookies = [NSHTTPCookie requestHeaderFieldsWithCookies:[self requestCookies]];
    for (NSString * cookieKey in cookies) { //拿到cookie值
        NSString * cookieValue = [cookies objectForKey:cookieKey];
        if ([cookieKey length] && [cookieValue length]) {
            CFHTTPMessageSetHeaderFieldValue(request, (__bridge CFStringRef)cookieKey, (__bridge CFStringRef)cookieValue);//设置到request的 head里
        }
    }
 
    // set header for http basic auth
     //设置http的基础auth,用户名密码认证
    if (_url.user.length && _url.password.length) {
        NSData *userAndPassword = [[NSString stringWithFormat:@"%@:%@", _url.user, _url.password] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *userAndPasswordBase64Encoded;
        if ([keyBytes respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
            userAndPasswordBase64Encoded = [userAndPassword base64EncodedStringWithOptions:0];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            userAndPasswordBase64Encoded = [userAndPassword base64Encoding];
#pragma clang diagnostic pop
        }
        //编码后用户名密码
        _basicAuthorizationString = [NSString stringWithFormat:@"Basic %@", userAndPasswordBase64Encoded];
        CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Authorization"), (__bridge CFStringRef)_basicAuthorizationString); //设置head Authorization
    }
    
    //web socket规范head,各种请求头
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Upgrade"), CFSTR("websocket"));
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Connection"), CFSTR("Upgrade"));
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Key"), (__bridge CFStringRef)_secKey);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Version"), (__bridge CFStringRef)[NSString stringWithFormat:@"%ld", (long)_webSocketVersion]);
    
    //设置request的原始 Url
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Origin"), (__bridge CFStringRef)_url.SR_origin);
    
    //用户初始化的协议数组，可以约束websocket的一些行为
    if (_requestedProtocols) {
        CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Protocol"), (__bridge CFStringRef)[_requestedProtocols componentsJoinedByString:@", "]);
    }

    //把_urlRequest中原有的head 设置到request中去
    [_urlRequest.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        CFHTTPMessageSetHeaderFieldValue(request, (__bridge CFStringRef)key, (__bridge CFStringRef)obj);
    }];
    
    /*
     Connection = Upgrade;
     Host = "123.207.136.134:9010";
     Origin = "http://123.207.136.134:9010";
     "Sec-WebSocket-Key" = "KcrT4qo8KPlQBDZhJ5GPrA==";
     "Sec-WebSocket-Version" = 13;
     Upgrade = websocket;
     */
    //返回一个序列化 , CFBridgingRelease和 __bridge transfer一个意思， CFHTTPMessageCopySerializedMessage copy一份新的并且序列化，返回CFDataRef
    NSData *message = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(request));
    
    CFRelease(request);

     //用outputStream 发送http请求
    [self _writeData:message];
    
     //读取http的头部
    [self _readHTTPHeader];
}

- (void)_initializeStreams;
{
    assert(_url.port.unsignedIntValue <= UINT32_MAX);//port值小于UINT32_MAX
    uint32_t port = _url.port.unsignedIntValue; // 拿到端口
    
    //如果端口号为0，给个默认值，http 80 https 443;
    if (port == 0) {
        if (!_secure) {
            port = 80;
        } else {
            port = 443;
        }
    }
    NSString *host = _url.host;
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    //用host创建读写stream,Host和port就绑定在一起了
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);
    
    //把C语言的输入输出流转化成OC对象
    //CFBridgingRelease 非OC指针指向OC
    _outputStream = CFBridgingRelease(writeStream);
    _inputStream = CFBridgingRelease(readStream);
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    /*
     这里为什么要用CFStream创建NSInputStream和NSOutputStream ？
     NSStream类不支持连接到远程主机,CFStream支持.两者可以转换。
     CFStreamCreatePairWithSocketToHost函数并传递主机名和端口号，来获取一个CFReadStreamRef和一个CFWriteStreamRef来进行通信，然后我们可以将它们转换为NSInputStream和NSOutputStream对象来处理。
     */
}

- (void)_updateSecureStreamOptions;
{
    if (_secure) { // 安全型协议的SSL配置
        NSMutableDictionary *SSLOptions = [[NSMutableDictionary alloc] init];
        
        [_outputStream setProperty:(__bridge id)kCFStreamSocketSecurityLevelNegotiatedSSL forKey:(__bridge id)kCFStreamPropertySocketSecurityLevel];
        
        // If we're using pinned certs, don't validate the certificate chain
        if ([_urlRequest SR_SSLPinnedCertificates].count) {
            [SSLOptions setValue:@NO forKey:(__bridge id)kCFStreamSSLValidatesCertificateChain];
        }
        
#if DEBUG
        self.allowsUntrustedSSLCertificates = YES;
#endif

        if (self.allowsUntrustedSSLCertificates) {
            [SSLOptions setValue:@NO forKey:(__bridge id)kCFStreamSSLValidatesCertificateChain];
            SRFastLog(@"Allowing connection to any root cert");
        }
        
        [_outputStream setProperty:SSLOptions
                            forKey:(__bridge id)kCFStreamPropertySSLSettings];
    }
    
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    [self setupNetworkServiceType:_urlRequest.networkServiceType];
}

- (void)setupNetworkServiceType:(NSURLRequestNetworkServiceType)requestNetworkServiceType
{
    NSString *networkServiceType;
    switch (requestNetworkServiceType) {
        case NSURLNetworkServiceTypeDefault:
            break;
        case NSURLNetworkServiceTypeVoIP: {
            networkServiceType = NSStreamNetworkServiceTypeVoIP;
#if TARGET_OS_IPHONE && __IPHONE_9_0
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_3) {
                static dispatch_once_t predicate;
                dispatch_once(&predicate, ^{
                    NSLog(@"SocketRocket: %@ - this service type is deprecated in favor of using PushKit for VoIP control", networkServiceType);
                });
            }
#endif
            break;
        }
        case NSURLNetworkServiceTypeVideo:
            networkServiceType = NSStreamNetworkServiceTypeVideo;
            break;
        case NSURLNetworkServiceTypeBackground:
            networkServiceType = NSStreamNetworkServiceTypeBackground;
            break;
        case NSURLNetworkServiceTypeVoice:
            networkServiceType = NSStreamNetworkServiceTypeVoice;
            break;
    }
    
    if (networkServiceType != nil) {
        [_inputStream setProperty:networkServiceType forKey:NSStreamNetworkServiceType];
        [_outputStream setProperty:networkServiceType forKey:NSStreamNetworkServiceType];
    }
}
//建立连接
- (void)openConnection;
{
    /*
     1> 如果是ws,https: _outputStream进行SSL配置
     2> _outputStream 和 _inputStream 进行networkServiceType配置
     */
    [self _updateSecureStreamOptions];
    
    if (!_scheduledRunloops.count) {
        //SR_networkRunLoop会创建一个带runloop的常驻子线程，模式为NSDefaultRunLoopMode。
        [self scheduleInRunLoop:[NSRunLoop SR_networkRunLoop] forMode:NSDefaultRunLoopMode];
    }
    
    
    [_outputStream open];
    [_inputStream open]; //open后会调用代理方法
    
    /*
     开始连接:
     1> 开启子线程，指定runloop
     2> 开启流：调用流的open方法
     */
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
{
    [_outputStream scheduleInRunLoop:aRunLoop forMode:mode];
    [_inputStream scheduleInRunLoop:aRunLoop forMode:mode];
    
    [_scheduledRunloops addObject:@[aRunLoop, mode]];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
{
    [_outputStream removeFromRunLoop:aRunLoop forMode:mode];
    [_inputStream removeFromRunLoop:aRunLoop forMode:mode];
    
    [_scheduledRunloops removeObject:@[aRunLoop, mode]];
}

- (void)close;
{
    [self closeWithCode:SRStatusCodeNormal reason:nil];
}

- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;
{
    assert(code);
    dispatch_async(_workQueue, ^{
        if (self.readyState == SR_CLOSING || self.readyState == SR_CLOSED) {
            return;
        }
        
        BOOL wasConnecting = self.readyState == SR_CONNECTING;
        
        self.readyState = SR_CLOSING;
        
        SRFastLog(@"Closing with code %d reason %@", code, reason);
        
        if (wasConnecting) {
            [self closeConnection];
            return;
        }

        size_t maxMsgSize = [reason maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *mutablePayload = [[NSMutableData alloc] initWithLength:sizeof(uint16_t) + maxMsgSize];
        NSData *payload = mutablePayload;
        // EndianU16_BtoN作用 举例:1000 转成 03e8 = 0000 0011 1110 1000
        ((uint16_t *)mutablePayload.mutableBytes)[0] = EndianU16_BtoN(code);
        
        if (reason) {
            NSRange remainingRange = {0};
            
            NSUInteger usedLength = 0;
            
            BOOL success = [reason getBytes:(char *)mutablePayload.mutableBytes + sizeof(uint16_t) maxLength:payload.length - sizeof(uint16_t) usedLength:&usedLength encoding:NSUTF8StringEncoding options:NSStringEncodingConversionExternalRepresentation range:NSMakeRange(0, reason.length) remainingRange:&remainingRange];
            #pragma unused (success)
            
            assert(success);
            assert(remainingRange.length == 0);

            if (usedLength != maxMsgSize) {
                payload = [payload subdataWithRange:NSMakeRange(0, usedLength + sizeof(uint16_t))];
            }
        }
        
        
        [self _sendFrameWithOpcode:SROpCodeConnectionClose data:payload];
    });
}

- (void)_closeWithProtocolError:(NSString *)message;
{
    // Need to shunt this on the _callbackQueue first to see if they received any messages 
    [self _performDelegateBlock:^{
        [self closeWithCode:SRStatusCodeProtocolError reason:message];
        dispatch_async(_workQueue, ^{
            [self closeConnection];
        });
    }];
}

- (void)_failWithError:(NSError *)error;
{
    dispatch_async(_workQueue, ^{
        if (self.readyState != SR_CLOSED) {
            _failed = YES;
            [self _performDelegateBlock:^{
                if ([self.delegate respondsToSelector:@selector(webSocket:didFailWithError:)]) {
                    [self.delegate webSocket:self didFailWithError:error];
                }
            }];

            //协议规定:如果连接没有被打开，或者由于直连失败或者代理返回了一个错误，那么客户端必须断开WebSocket连接，并且停止重试连接。
            self.readyState = SR_CLOSED;

            SRFastLog(@"Failing with error %@", error.localizedDescription);
            // 断开连接
            [self closeConnection];
            [self _scheduleCleanup];
        }
    });
}

// 把NSData拼接到_outputBuffer上
// 记录_outputBufferOffset的位置
//向服务端发送数据
- (void)_writeData:(NSData *)data;
{
    [self assertOnWorkQueue];

    if (_closeWhenFinishedWriting) {
            return;
    }
    [_outputBuffer appendData:data]; // 拼接到buffer上
    [self _pumpWriting];
}

- (void)send:(id)data;
{
    NSAssert(self.readyState != SR_CONNECTING, @"Invalid State: Cannot call send: until connection is open");
    // TODO: maybe not copy this for performance
    data = [data copy];
    dispatch_async(_workQueue, ^{
        if ([data isKindOfClass:[NSString class]]) {
            [self _sendFrameWithOpcode:SROpCodeTextFrame data:[(NSString *)data dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([data isKindOfClass:[NSData class]]) {
            [self _sendFrameWithOpcode:SROpCodeBinaryFrame data:data];
        } else if (data == nil) {
            [self _sendFrameWithOpcode:SROpCodeTextFrame data:data];
        } else {
            assert(NO);
        }
    });
}

- (void)sendPing:(NSData *)data;
{
    NSAssert(self.readyState == SR_OPEN, @"Invalid State: Cannot call send: until connection is open");
    // TODO: maybe not copy this for performance
    data = [data copy] ?: [NSData data]; // It's okay for a ping to be empty
    dispatch_async(_workQueue, ^{
        [self _sendFrameWithOpcode:SROpCodePing data:data];
    });
}

- (void)handlePing:(NSData *)pingData;
{
    // Need to pingpong this off _callbackQueue first to make sure messages happen in order
    [self _performDelegateBlock:^{
        dispatch_async(_workQueue, ^{
            [self _sendFrameWithOpcode:SROpCodePong data:pingData];
        });
    }];
}

- (void)handlePong:(NSData *)pongData;
{
    SRFastLog(@"Received pong");
    [self _performDelegateBlock:^{
        if ([self.delegate respondsToSelector:@selector(webSocket:didReceivePong:)]) {
            [self.delegate webSocket:self didReceivePong:pongData];
        }
    }];
}

- (void)_handleMessage:(id)message
{
    SRFastLog(@"Received message");
    [self _performDelegateBlock:^{
        [self.delegate webSocket:self didReceiveMessage:message];
    }];
}


static inline BOOL closeCodeIsValid(int closeCode) {
    if (closeCode < 1000) {
        return NO;
    }
    
    if (closeCode >= 1000 && closeCode <= 1011) {
        if (closeCode == 1004 ||
            closeCode == 1005 ||
            closeCode == 1006) {
            return NO;
        }
        return YES;
    }
    
    if (closeCode >= 3000 && closeCode <= 3999) {
        return YES;
    }
    
    if (closeCode >= 4000 && closeCode <= 4999) {
        return YES;
    }

    return NO;
}

//  Note from RFC:
//
//  If there is a body, the first two
//  bytes of the body MUST be a 2-byte unsigned integer (in network byte
//  order) representing a status code with value /code/ defined in
//  Section 7.4.  Following the 2-byte integer the body MAY contain UTF-8
//  encoded data with value /reason/, the interpretation of which is not
//  defined by this specification.

- (void)handleCloseWithData:(NSData *)data;
{
    size_t dataSize = data.length;
    __block uint16_t closeCode = 0;
    
    SRFastLog(@"Received close frame");
    
    if (dataSize == 1) {
        // TODO handle error
        [self _closeWithProtocolError:@"Payload for close must be larger than 2 bytes"];
        return;
    } else if (dataSize >= 2) {
        [data getBytes:&closeCode length:sizeof(closeCode)];
        _closeCode = EndianU16_BtoN(closeCode);
        if (!closeCodeIsValid(_closeCode)) {
            [self _closeWithProtocolError:[NSString stringWithFormat:@"Cannot have close code of %d", _closeCode]];
            return;
        }
        if (dataSize > 2) {
            _closeReason = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(2, dataSize - 2)] encoding:NSUTF8StringEncoding];
            if (!_closeReason) {
                [self _closeWithProtocolError:@"Close reason MUST be valid UTF-8"];
                return;
            }
        }
    } else {
        _closeCode = SRStatusNoStatusReceived;
    }
    
    [self assertOnWorkQueue];
    
    if (self.readyState == SR_OPEN) {
        [self closeWithCode:1000 reason:nil];
    }
    dispatch_async(_workQueue, ^{
        [self closeConnection];
    });
}

- (void)closeConnection;
{
    [self assertOnWorkQueue];
    SRFastLog(@"Trying to disconnect");
    _closeWhenFinishedWriting = YES;
    [self _pumpWriting];
}

- (void)_handleFrameWithData:(NSData *)frameData opCode:(NSInteger)opcode;
{                
    // Check that the current data is valid UTF8
    
    BOOL isControlFrame = (opcode == SROpCodePing || opcode == SROpCodePong || opcode == SROpCodeConnectionClose);
    if (!isControlFrame) {
        [self _readFrameNew];
    } else {
        dispatch_async(_workQueue, ^{
            [self _readFrameContinue];
        });
    }
    
    //frameData will be copied before passing to handlers
    //otherwise there can be misbehaviours when value at the pointer is changed
    switch (opcode) { //根据不同类型的帧 作不同的处理
        case SROpCodeTextFrame: {
            if ([self.delegate respondsToSelector:@selector(webSocketShouldConvertTextFrameToString:)] && ![self.delegate webSocketShouldConvertTextFrameToString:self]) {
                [self _handleMessage:[frameData copy]];
            } else {
                NSString *str = [[NSString alloc] initWithData:frameData encoding:NSUTF8StringEncoding];
                if (str == nil && frameData) {
                    [self closeWithCode:SRStatusCodeInvalidUTF8 reason:@"Text frames must be valid UTF-8"];
                    dispatch_async(_workQueue, ^{
                        [self closeConnection];
                    });
                    return;
                }
                [self _handleMessage:str];
            }
            break;
        }
        case SROpCodeBinaryFrame:
            [self _handleMessage:[frameData copy]];
            break;
        case SROpCodeConnectionClose:
            [self handleCloseWithData:[frameData copy]];
            break;
        case SROpCodePing:
            [self handlePing:[frameData copy]];
            break;
        case SROpCodePong:
            [self handlePong:[frameData copy]];
            break;
        default:
            [self _closeWithProtocolError:[NSString stringWithFormat:@"Unknown opcode %ld", (long)opcode]];
            // TODO: Handle invalid opcode
            break;
    }
}
/*
 1> frame_header结构体作为参数
 
 */
- (void)_handleFrameHeader:(frame_header)frame_header curData:(NSData *)curData;
{
    assert(frame_header.opcode != 0);
    
    if (self.readyState == SR_CLOSED) {
        return;
    }
    
    /*
     判断控制帧：控制帧是通过操作码最高位的值为1来进行区分的。当前已经定义的控制帧操作码包括0x8（关闭），0x9（心跳Ping）和0xA（心跳Pong）,控制帧是用于WebSocket的通信状态的。控制帧可以被插入到消息片段中进行传输。
     */
    BOOL isControlFrame = (frame_header.opcode == SROpCodePing || frame_header.opcode == SROpCodePong || frame_header.opcode == SROpCodeConnectionClose);
    
    if (isControlFrame && !frame_header.fin) {
        [self _closeWithProtocolError:@"Fragmented control frames not allowed"];
        return;
    }
    
    //所有的控制帧必须有一个126字节或者更小的负载长度，并且不能被分片。
    if (isControlFrame && frame_header.payload_length >= 126) {
        [self _closeWithProtocolError:@"Control frames cannot have payloads larger than 126 bytes"];
        return;
    }
    
    if (!isControlFrame) {
        _currentFrameOpcode = frame_header.opcode;
        _currentFrameCount += 1;
    }
    
    if (frame_header.payload_length == 0) {
        if (isControlFrame) { //如果是控制帧
            [self _handleFrameWithData:curData opCode:frame_header.opcode];
        } else {
            if (frame_header.fin) {
                [self _handleFrameWithData:_currentFrameData opCode:frame_header.opcode];
            } else {
                // TODO add assert that opcode is not a control;
                [self _readFrameContinue];
            }
        }
    } else {//添加消费者读Payload数据:
        assert(frame_header.payload_length <= SIZE_T_MAX);
        [self _addConsumerWithDataLength:(size_t)frame_header.payload_length callback:^(SRWebSocket *self, NSData *newData) {
            if (isControlFrame) { //如果是控制帧
                [self _handleFrameWithData:newData opCode:frame_header.opcode];
            } else {
                if (frame_header.fin) {
                    [self _handleFrameWithData:self->_currentFrameData opCode:frame_header.opcode];
                } else {
                    // TODO add assert that opcode is not a control;
                    [self _readFrameContinue];
                }
                
            }
        } readToCurrentFrame:!isControlFrame unmaskBytes:frame_header.masked];
    }
}
//https://www.jianshu.com/p/2f7a9582ae97
/* From RFC:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+
 */

static const uint8_t SRFinMask          = 0x80; // 1000 0000
static const uint8_t SROpCodeMask       = 0x0F; // 0000 1111
static const uint8_t SRRsvMask          = 0x70; // 0111 0000
static const uint8_t SRMaskMask         = 0x80; // 1000 0000
static const uint8_t SRPayloadLenMask   = 0x7F; // 0111 1111

//开始读取当前消息帧
/*
 这个方法是先去读取了当前消息帧的前2个字节
 然后会去对头部信息进行一些判断，但是最主要的还是去获取payload，也就是真实数据的长度
 */
- (void)_readFrameContinue;
{
    assert((_currentFrameCount == 0 && _currentFrameOpcode == 0) || (_currentFrameCount > 0 && _currentFrameOpcode > 0));
    //参考上表,2个字节，是16位。到Payload len 结束。数据帧的头部
    [self _addConsumerWithDataLength:2 callback:^(SRWebSocket *self, NSData *data) {
        __block frame_header header = {0};
        
        const uint8_t *headerBuffer = data.bytes;
        assert(data.length >= 2);
        
         //判断第一帧 FIN
        if (headerBuffer[0] & SRRsvMask) {
            [self _closeWithProtocolError:@"Server used RSV bits"];
            return;
        }
        
        //得到Qpcode
        uint8_t receivedOpcode = (SROpCodeMask & headerBuffer[0]);
        
        //判断帧类型，是否是指定的控制帧
        BOOL isControlFrame = (receivedOpcode == SROpCodePing || receivedOpcode == SROpCodePong || receivedOpcode == SROpCodeConnectionClose);
        
        //如果不是指定帧，而且receivedOpcode不等于0，而且_currentFrameCount消息帧大于0，错误关闭
        if (!isControlFrame && receivedOpcode != 0 && self->_currentFrameCount > 0) {
            [self _closeWithProtocolError:@"all data frames after the initial data frame must have opcode 0"];
            return;
        }
        
         // 没消息
        if (receivedOpcode == 0 && self->_currentFrameCount == 0) {
            [self _closeWithProtocolError:@"cannot continue a message"];
            return;
        }
        //正常读取
        //得到opcode
        header.opcode = receivedOpcode == 0 ? self->_currentFrameOpcode : receivedOpcode;
        
         //得到fin
        header.fin = !!(SRFinMask & headerBuffer[0]);
        
        //得到Mask
        header.masked = !!(SRMaskMask & headerBuffer[1]);
          //得到数据长度
        header.payload_length = SRPayloadLenMask & headerBuffer[1];
        
        headerBuffer = NULL;
        
        //客户端不能接受掩码的数据
        if (header.masked) {
            [self _closeWithProtocolError:@"Client must receive unmasked data"];
        }
        
        size_t extra_bytes_needed = header.masked ? sizeof(_currentReadMaskKey) : 0;
        //得到长度
        /*
         [Payload len]小于126,用[Payload len]来读后续的Payload数据;
         [Payload len]大于等于126,用[Extended payload length]来读后续的Payload数据;
         当Payload len小于126时,Payload len所代表的数值也就是数据长度.
         当Payload len大于等于126时,我们就需要读Payload len后面的Extended payload length,Extended payload length所代表的数值也就是数据长度.
         */
        if (header.payload_length == 126) {
            extra_bytes_needed += sizeof(uint16_t);
        } else if (header.payload_length == 127) {
            extra_bytes_needed += sizeof(uint64_t);
        }

        //extra_bytes_needed就是Extended payload length
        if (extra_bytes_needed == 0) {//Extended payload length为0,直接进入后续读取操作;
            [self _handleFrameHeader:header curData:self->_currentFrameData];
        } else {
            //Extended payload length不为0,添加消费者,改变读取数据的偏移,移动到Payload数据起始的位置;
            [self _addConsumerWithDataLength:extra_bytes_needed callback:^(SRWebSocket *self, NSData *data) {
                size_t mapped_size = data.length;
                #pragma unused (mapped_size)
                const void *mapped_buffer = data.bytes;
                size_t offset = 0;
                
                if (header.payload_length == 126) {
                    assert(mapped_size >= sizeof(uint16_t));
                    uint16_t newLen = EndianU16_BtoN(*(uint16_t *)(mapped_buffer));
                    header.payload_length = newLen;
                    offset += sizeof(uint16_t);
                } else if (header.payload_length == 127) {
                    assert(mapped_size >= sizeof(uint64_t));
                    header.payload_length = EndianU64_BtoN(*(uint64_t *)(mapped_buffer));
                    offset += sizeof(uint64_t);
                } else {
                    assert(header.payload_length < 126 && header.payload_length >= 0);
                }
                
                if (header.masked) {
                    assert(mapped_size >= sizeof(_currentReadMaskOffset) + offset);
                    memcpy(self->_currentReadMaskKey, ((uint8_t *)mapped_buffer) + offset, sizeof(self->_currentReadMaskKey));
                }
                 //把已读到的数据，和header传出去
                [self _handleFrameHeader:header curData:self->_currentFrameData];
            } readToCurrentFrame:NO unmaskBytes:NO];
        }
    } readToCurrentFrame:NO unmaskBytes:NO];
}
//读取新的消息帧
- (void)_readFrameNew;
{
    dispatch_async(_workQueue, ^{
        //清空上一帧的信息
        [self->_currentFrameData setLength:0];
        
        self->_currentFrameOpcode = 0;
        self->_currentFrameCount = 0;
        self->_readOpCount = 0;
        self->_currentStringScanPosition = 0;
        //读取一个新的数据帧
        [self _readFrameContinue];
    });
}

//发出HTTP的报文
// 如果数据比较大，这个方法有可能会被调用多次
- (void)_pumpWriting;
{
    [self assertOnWorkQueue];
    
    NSUInteger dataLength = _outputBuffer.length; // buffer的长度，要发送的数据总大小
    //（buffer的总长度 - 已经读到的位置），也就是剩余未读的字节数
    // 有剩余字节数 && 接收者能被写入
    if (dataLength - _outputBufferOffset > 0 && _outputStream.hasSpaceAvailable) {
        
        //向服务端发送http请求
        /*
         1> - (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
         方法意思：读取len长度的内容到buffer中,返回值为读取的实际长度，所以最大为len
         2> bytes方法指向接收者管理的一段连续的内存,是一个指针
         
         _outputBuffer.bytes指向的是_outputBuffer的内存首地址。可以理解为数据的第0个位置
         _outputBuffer.bytes + _outputBufferOffset ，从距离首地址_outputBufferOffset的位置处
         write:_outputBuffer.bytes + _outputBufferOffset: 表示从距离首地址_outputBufferOffset的位置处开始写数据
         maxLength: 限定长度是为了保证取到的数据正确。不至于取多。因为bytes指向的是一块内存区域
         */
        
        //把_outputBuffer对象上数据流写入到_outputStream对象上
        NSInteger bytesWritten = [_outputStream write:_outputBuffer.bytes + _outputBufferOffset maxLength:dataLength - _outputBufferOffset];
        if (bytesWritten == -1) { // -1 说明写入发生了错误
            [self _failWithError:[NSError errorWithDomain:SRWebSocketErrorDomain code:2145 userInfo:[NSDictionary dictionaryWithObject:@"Error writing to stream" forKey:NSLocalizedDescriptionKey]]];
             return;
        }
        
        _outputBufferOffset += bytesWritten; //当前发送到的位置
        
        //超过4KB && 写的位置大于总数据长度的一半
        // 重新生成buffer,重置偏移量
        if (_outputBufferOffset > 4096 && _outputBufferOffset > (_outputBuffer.length >> 1)) {
            _outputBuffer = [[NSMutableData alloc] initWithBytes:(char *)_outputBuffer.bytes + _outputBufferOffset length:_outputBuffer.length - _outputBufferOffset];
            _outputBufferOffset = 0;
        }
    }
    
    if (_closeWhenFinishedWriting && 
        _outputBuffer.length - _outputBufferOffset == 0 && 
        (_inputStream.streamStatus != NSStreamStatusNotOpen &&
         _inputStream.streamStatus != NSStreamStatusClosed) &&
        !_sentClose) {
        _sentClose = YES;
        
        @synchronized(self) {
            [_outputStream close];
            [_inputStream close];
            
            
            for (NSArray *runLoop in [_scheduledRunloops copy]) {
                [self unscheduleFromRunLoop:[runLoop objectAtIndex:0] forMode:[runLoop objectAtIndex:1]];
            }
        }
        
        if (!_failed) {
            [self _performDelegateBlock:^{
                if ([self.delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)]) {
                    [self.delegate webSocket:self didCloseWithCode:_closeCode reason:_closeReason wasClean:YES];
                }
            }];
        }
        
        [self _scheduleCleanup];
    }
}

- (void)_addConsumerWithScanner:(stream_scanner)consumer callback:(data_callback)callback;
{
    [self assertOnWorkQueue];
    [self _addConsumerWithScanner:consumer callback:callback dataLength:0];
}
//生产-消费者模式
- (void)_addConsumerWithDataLength:(size_t)dataLength callback:(data_callback)callback readToCurrentFrame:(BOOL)readToCurrentFrame unmaskBytes:(BOOL)unmaskBytes;
{   
    [self assertOnWorkQueue];
    assert(dataLength);
     //生产
    /*
     其实就是添加了一个stream_scanner类型的对象，到我们的_consumers数组中去了，以后我们读取数据，都会先取出_consumers中的消费者，要读取多少，就给你从_readBuffer里去读多少数据。
     */
    //websocket建立连接后，Scanner参数传的一直是nil.
    [_consumers addObject:[_consumerPool consumerWithScanner:nil handler:callback bytesNeeded:dataLength readToCurrentFrame:readToCurrentFrame unmaskBytes:unmaskBytes]];
    
    //消费
    [self _pumpScanner];
}
//指定数据读取
- (void)_addConsumerWithScanner:(stream_scanner)consumer callback:(data_callback)callback dataLength:(size_t)dataLength;
{    
    [self assertOnWorkQueue];
    //生产
    [_consumers addObject:[_consumerPool consumerWithScanner:consumer handler:callback bytesNeeded:dataLength readToCurrentFrame:NO unmaskBytes:NO]];
    //消费
    [self _pumpScanner];
}


- (void)_scheduleCleanup
{
    @synchronized(self) {
        if (_cleanupScheduled) {
            return;
        }
        
        _cleanupScheduled = YES;
        
        // Cleanup NSStream delegate's in the same RunLoop used by the streams themselves:
        // This way we'll prevent race conditions between handleEvent and SRWebsocket's dealloc
        NSTimer *timer = [NSTimer timerWithTimeInterval:(0.0f) target:self selector:@selector(_cleanupSelfReference:) userInfo:nil repeats:NO];
        [[NSRunLoop SR_networkRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
}

- (void)_cleanupSelfReference:(NSTimer *)timer
{
    @synchronized(self) {
        // Nuke NSStream delegate's
        _inputStream.delegate = nil;
        _outputStream.delegate = nil;
        
        // Remove the streams, right now, from the networkRunLoop
        [_inputStream close];
        [_outputStream close];
    }
    
    // Cleanup selfRetain in the same GCD queue as usual
    dispatch_async(_workQueue, ^{
        _selfRetain = nil;
    });
}


static const char CRLFCRLFBytes[] = {'\r', '\n', '\r', '\n'};
//读取CRLFCRLFBytes,直到回调回来
- (void)_readUntilHeaderCompleteWithCallback:(data_callback)dataHandler;
{
    [self _readUntilBytes:CRLFCRLFBytes length:sizeof(CRLFCRLFBytes) callback:dataHandler];
}
/*
 读取头部的方法，这里用了\r\n\r\n，每次读到这个标识符为止，就是读取了一个完整的WebSocket的消息帧头部。
 */
- (void)_readUntilBytes:(const void *)bytes length:(size_t)length callback:(data_callback)dataHandler;
{
    // TODO optimize so this can continue from where we last searched
    //消费者需要消费的数据大小
    /*
     举例:
     buffer = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: QSC0hlw/W+lJWquOxEMqno4iSF4=\r\n\r\nA80562D-B6CD-49AF-A860-AF4576BD6F3E/iosWebSocket.app/iosWebSocket"
     bytes = \r\n\r\n
     
     最后得到的完整消息帧头部：
     Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: QSC0hlw/W+lJWquOxEMqno4iSF4=
     
     
     一个字符一个字符的遍历buffer,遇到\r或者\n:
     match_count 加1
     */
    
    /*
     block的实现的方式上彻底解决了数据粘包，断包的可能。
     数据是通过CFStream流的方式回调回来的，每次拿到流数据，都是先放在数据缓冲区中，然后去读当前消息帧的头部，得到当前数据包的大小，然后再去创建消费者对象consumer，去读取缓冲区指定数据包大小的内容，读完才会回调给我们上层用户，所以，我们如果用SRWebSocket完全不需要考虑数据断包、粘包的问题，每次到达的数据，都是一条完整的数据。
     */
    stream_scanner consumer = ^size_t(NSData *data) {
        __block size_t found_size = 0;
        __block size_t match_count = 0;
        
        size_t size = data.length;//得到数据长度
        const unsigned char *buffer = data.bytes;//得到数据指针,字符数组
        for (size_t i = 0; i < size; i++ ) {
            //匹配字符
            if (((const unsigned char *)buffer)[i] == ((const unsigned char *)bytes)[match_count]) {
                match_count += 1;//匹配数+1
                /*
                 每次读到这个\r\n\r\n标识符为止，就是读取了一个完整的WebSocket的数据帧头部。
                 */
                if (match_count == length) { //length == 4
                    found_size = i + 1;//读取数据长度等于 i+ 1
                    break;
                }
            } else {
                match_count = 0;
            }
        }
        return found_size;//返回要读取数据的长度，没匹配成功就是0
    };
    
    //验证服务端http响应的时候,才传consumer
    [self _addConsumerWithScanner:consumer callback:dataHandler];
}


// Returns true if did work
- (BOOL)_innerPumpScanner {
    
    BOOL didWork = NO;
    
    if (self.readyState >= SR_CLOSED) {
        return didWork;
    }
    
    if (!_consumers.count) {
        return didWork;
    }
    
    size_t curSize = _readBuffer.length - _readBufferOffset;
    if (!curSize) {
        return didWork;
    }
    
    SRIOConsumer *consumer = [_consumers objectAtIndex:0];
    
    size_t bytesNeeded = consumer.bytesNeeded;
    
    size_t foundSize = 0;
    if (consumer.consumer) {
        NSData *tempView = [NSData dataWithBytesNoCopy:(char *)_readBuffer.bytes + _readBufferOffset length:_readBuffer.length - _readBufferOffset freeWhenDone:NO];  
        foundSize = consumer.consumer(tempView); //读取的一定是完整的数据帧，返回数据帧的大小
    } else {
        assert(consumer.bytesNeeded);
        if (curSize >= bytesNeeded) {
            foundSize = bytesNeeded;
        } else if (consumer.readToCurrentFrame) {
            foundSize = curSize;
        }
    }
    
    NSData *slice = nil;
    if (consumer.readToCurrentFrame || foundSize) {
        NSRange sliceRange = NSMakeRange(_readBufferOffset, foundSize);
        slice = [_readBuffer subdataWithRange:sliceRange];
        
        _readBufferOffset += foundSize;
        
        if (_readBufferOffset > 4096 && _readBufferOffset > (_readBuffer.length >> 1)) {
            _readBuffer = [[NSMutableData alloc] initWithBytes:(char *)_readBuffer.bytes + _readBufferOffset length:_readBuffer.length - _readBufferOffset];
            _readBufferOffset = 0;
        }
        
        if (consumer.unmaskBytes) {
            NSMutableData *mutableSlice = [slice mutableCopy];
            
            NSUInteger len = mutableSlice.length;
            uint8_t *bytes = mutableSlice.mutableBytes;
            
            for (NSUInteger i = 0; i < len; i++) {
                bytes[i] = bytes[i] ^ _currentReadMaskKey[_currentReadMaskOffset % sizeof(_currentReadMaskKey)];
                _currentReadMaskOffset += 1;
            }
            
            slice = mutableSlice;
        }
        
        if (consumer.readToCurrentFrame) {
            [_currentFrameData appendData:slice];
            
            _readOpCount += 1;
            
            if (_currentFrameOpcode == SROpCodeTextFrame) {
                // Validate UTF8 stuff.
                size_t currentDataSize = _currentFrameData.length;
                if (_currentFrameOpcode == SROpCodeTextFrame && currentDataSize > 0) {
                    // TODO: Optimize the crap out of this.  Don't really have to copy all the data each time
                    
                    size_t scanSize = currentDataSize - _currentStringScanPosition;
                    
                    NSData *scan_data = [_currentFrameData subdataWithRange:NSMakeRange(_currentStringScanPosition, scanSize)];
                    int32_t valid_utf8_size = validate_dispatch_data_partial_string(scan_data);
                    
                    if (valid_utf8_size == -1) {
                        [self closeWithCode:SRStatusCodeInvalidUTF8 reason:@"Text frames must be valid UTF-8"];
                        dispatch_async(_workQueue, ^{
                            [self closeConnection];
                        });
                        return didWork;
                    } else {
                        _currentStringScanPosition += valid_utf8_size;
                    }
                } 
                
            }
            
            consumer.bytesNeeded -= foundSize;
            
            if (consumer.bytesNeeded == 0) {
                [_consumers removeObjectAtIndex:0];
                consumer.handler(self, nil);
                [_consumerPool returnConsumer:consumer];
                didWork = YES;
            }
        } else if (foundSize) {
            [_consumers removeObjectAtIndex:0];
            consumer.handler(self, slice);
            [_consumerPool returnConsumer:consumer];
            didWork = YES;
        }
    }
    return didWork;
}
//消费者读数据
-(void)_pumpScanner;
{
    [self assertOnWorkQueue];
    
     //判断是否正在消费
    if (!_isPumping) {
        _isPumping = YES;
    } else {
        return;
    }
    //循环检测
    while ([self _innerPumpScanner]) {
        
    }
    
    _isPumping = NO;
}

//#define NOMASK

static const size_t SRFrameHeaderOverhead = 32;
/*
 根据websocket协议,给data加上websocket的数据帧头部
 */
- (void)_sendFrameWithOpcode:(SROpCode)opcode data:(id)data;
{
    [self assertOnWorkQueue];
    
    if (nil == data) {
        return;
    }
    
    NSAssert([data isKindOfClass:[NSData class]] || [data isKindOfClass:[NSString class]], @"NSString or NSData");
    
    size_t payloadLength = [data isKindOfClass:[NSString class]] ? [(NSString *)data lengthOfBytesUsingEncoding:NSUTF8StringEncoding] : [data length];
        
    NSMutableData *frame = [[NSMutableData alloc] initWithLength:payloadLength + SRFrameHeaderOverhead];
    if (!frame) {
        [self closeWithCode:SRStatusCodeMessageTooBig reason:@"Message too big"];
        return;
    }
    uint8_t *frame_buffer = (uint8_t *)[frame mutableBytes];
    
    //2个十六进制是一个字节,总共8位
    //数据帧头部的第一个字节:包含了fin和opcode
    frame_buffer[0] = SRFinMask | opcode; //第一个字节
    
    BOOL useMask = YES;
#ifdef NOMASK
    useMask = NO;
#endif
    
    if (useMask) {
    // set the mask and header
        frame_buffer[1] |= SRMaskMask; //数据帧头部的mask值，客户端发送到服务端的必须置为1
    }
    
    size_t frame_buffer_size = 2; //数据帧头部总共为2个字节
    
    const uint8_t *unmasked_payload = NULL;
    if ([data isKindOfClass:[NSData class]]) {
        unmasked_payload = (uint8_t *)[data bytes]; // 要发送的数据的长度
    } else if ([data isKindOfClass:[NSString class]]) {
        unmasked_payload =  (const uint8_t *)[data UTF8String];
    } else {
        return;
    }
    //数据帧头部的Payload len设置
    if (payloadLength < 126) { //有效负载数据长度:如果值为0-125字节，那么就表示负载数据的长度
        frame_buffer[1] |= payloadLength;
    } else if (payloadLength <= UINT16_MAX) {
        frame_buffer[1] |= 126; //如果是126，那么接下来的2个bytes解释为16bit的无符号整形作为负载数据的长度。
        *((uint16_t *)(frame_buffer + frame_buffer_size)) = EndianU16_BtoN((uint16_t)payloadLength);
        frame_buffer_size += sizeof(uint16_t);
    } else {
        frame_buffer[1] |= 127;//如果是127，那么接下来的8个bytes解释为一个64bit的无符号整形（最高位的bit必须为0）作为负载数据的长度。
        *((uint64_t *)(frame_buffer + frame_buffer_size)) = EndianU64_BtoN((uint64_t)payloadLength);
        frame_buffer_size += sizeof(uint64_t);
    }
        
    if (!useMask) {
        for (size_t i = 0; i < payloadLength; i++) {
            frame_buffer[frame_buffer_size] = unmasked_payload[i];
            frame_buffer_size += 1;
        }
    } else {//​ 所有从客户端发往服务端的数据帧都已经与一个包含在这一帧中的32 bit的掩码进行过了运算
        //Masking-Key:掩码的key,占用4个字节
        uint8_t *mask_key = frame_buffer + frame_buffer_size;
        SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), (uint8_t *)mask_key);
        frame_buffer_size += sizeof(uint32_t);
        
        //发送的数据按位与mask-key进行异或运算
        // TODO: could probably optimize this with SIMD
        for (size_t i = 0; i < payloadLength; i++) {
            frame_buffer[frame_buffer_size] = unmasked_payload[i] ^ mask_key[i % sizeof(uint32_t)];//异或运算
            frame_buffer_size += 1;
        }
    }

    /*
     多出的字节：下面举的例子只是一种情况：
     相当于根据websocket的规定进行相关字段的设置：
     fin 1位
     opcode 4位
     mask 1位
     payload len: 7位
     以上占用2个字节。
     mask置为1时,
     mask-key占用4个字节
     */
    assert(frame_buffer_size <= [frame length]);
    frame.length = frame_buffer_size;
    [self _writeData:frame];
}
// 建立连接后会调用NSStream的代理方法
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode;
{
    __weak typeof(self) weakSelf = self;
    
    //  如果是ssl,而且_pinnedCertFound 为NO，而且事件类型是有可读数据未读，或者事件类型是还有空余空间可写
    if (_secure && !_pinnedCertFound && (eventCode == NSStreamEventHasBytesAvailable || eventCode == NSStreamEventHasSpaceAvailable)) {
        
        // 本地如果有证书
        NSArray *sslCerts = [_urlRequest SR_SSLPinnedCertificates]; //
        if (sslCerts) {
            
            // 获取服务端的SSL证书
            SecTrustRef secTrust = (__bridge SecTrustRef)[aStream propertyForKey:(__bridge id)kCFStreamPropertySSLPeerTrust];
            if (secTrust) {
                NSInteger numCerts = SecTrustGetCertificateCount(secTrust);
                for (NSInteger i = 0; i < numCerts && !_pinnedCertFound; i++) {
                    SecCertificateRef cert = SecTrustGetCertificateAtIndex(secTrust, i);
                    NSData *certData = CFBridgingRelease(SecCertificateCopyData(cert));
                    
                    for (id ref in sslCerts) {
                        SecCertificateRef trustedCert = (__bridge SecCertificateRef)ref;
                        NSData *trustedCertData = CFBridgingRelease(SecCertificateCopyData(trustedCert));
                        
                        if ([trustedCertData isEqualToData:certData]) {
                            _pinnedCertFound = YES;
                            break;
                        }
                    }
                }
            }
          //如果为NO，SSL认证失败，会断开连接，
            if (!_pinnedCertFound) {
                dispatch_async(_workQueue, ^{
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Invalid server cert" };
                    [weakSelf _failWithError:[NSError errorWithDomain:@"org.lolrus.SocketRocket" code:23556 userInfo:userInfo]];
                });
                return;
            } else if (aStream == _outputStream) {//如果流是输出流，则打开流成功
                dispatch_async(_workQueue, ^{
                    [self didConnect];//流打开成功后的操作，开始发送http请求建立连接
                });
            }
        }
    }

    dispatch_async(_workQueue, ^{
        [weakSelf safeHandleEvent:eventCode stream:aStream];
    });
}

- (void)safeHandleEvent:(NSStreamEvent)eventCode stream:(NSStream *)aStream
{
    NSLog(@"eventCode---%zd",eventCode);
        switch (eventCode) {
                /*
                 eventCode==NSStreamEventOpenCompleted代表socket连接建立完成;
                 WebSocket的开启会用HTTP报文做'前导',HTTP报文内会有字段:[Upgrade:websocket].
                 HTTP报文发给服务端,服务端会有数据回传,我们会'读'服务端回传的数据来判定WebSocket的开启是否成功.
                 */
            case NSStreamEventOpenCompleted: { // 连接成功
                SRFastLog(@"NSStreamEventOpenCompleted %@", aStream);
                if (self.readyState >= SR_CLOSING) {
                    return;
                }
                assert(_readBuffer);
                
                // didConnect fires after certificate verification if we're using pinned certificates.
                BOOL usingPinnedCerts = [[_urlRequest SR_SSLPinnedCertificates] count] > 0;
                if ((!_secure || !usingPinnedCerts) && self.readyState == SR_CONNECTING && aStream == _inputStream) {
                    [self didConnect];
                }
                [self _pumpWriting];
                [self _pumpScanner];
                break;
            }
                
            case NSStreamEventErrorOccurred: {
                SRFastLog(@"NSStreamEventErrorOccurred %@ %@", aStream, [[aStream streamError] copy]);
                /// TODO specify error better!
                [self _failWithError:aStream.streamError];
                _readBufferOffset = 0;
                [_readBuffer setLength:0];
                break;
                
            }
                
            case NSStreamEventEndEncountered: {
                [self _pumpScanner];
                SRFastLog(@"NSStreamEventEndEncountered %@", aStream);
                if (aStream.streamError) {
                    [self _failWithError:aStream.streamError];
                } else {
                    dispatch_async(_workQueue, ^{
                        if (self.readyState != SR_CLOSED) {
                            self.readyState = SR_CLOSED;
                            [self _scheduleCleanup];
                        }
                        
                        if (!_sentClose && !_failed) {
                            _sentClose = YES;
                            // If we get closed in this state it's probably not clean because we should be sending this when we send messages
                            [self _performDelegateBlock:^{
                                if ([self.delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)]) {
                                    [self.delegate webSocket:self didCloseWithCode:SRStatusCodeGoingAway reason:@"Stream end encountered" wasClean:NO];
                                }
                            }];
                        }
                    });
                }
                
                break;
            }
                
            case NSStreamEventHasBytesAvailable: {
                SRFastLog(@"NSStreamEventHasBytesAvailable %@", aStream);
                const int bufferSize = 2048;
                uint8_t buffer[bufferSize];
                
                while (_inputStream.hasBytesAvailable) { //从服务端返回的数据
                     //读取数据，一次读2048
                    NSInteger bytes_read = [_inputStream read:buffer maxLength:bufferSize];
                    
                    if (bytes_read > 0) { //拼接数据
                        [_readBuffer appendBytes:buffer length:bytes_read];
                    } else if (bytes_read < 0) {
                        [self _failWithError:_inputStream.streamError];//读取错误
                    }
                     //如果读取的不等于最大的，说明读完了，跳出循环
                    if (bytes_read != bufferSize) {
                        break;
                    }
                };
                [self _pumpScanner]; //消费数据
                break;
            }
                
            case NSStreamEventHasSpaceAvailable: {
                SRFastLog(@"NSStreamEventHasSpaceAvailable %@", aStream);
                [self _pumpWriting]; // 向服务端发送数据
                break;
            }
                
            default:
                SRFastLog(@"(default)  %@", aStream);
                break;
        }
}

@end


@implementation SRIOConsumer

@synthesize bytesNeeded = _bytesNeeded;
@synthesize consumer = _scanner;
@synthesize handler = _handler;
@synthesize readToCurrentFrame = _readToCurrentFrame;
@synthesize unmaskBytes = _unmaskBytes;

- (void)setupWithScanner:(stream_scanner)scanner handler:(data_callback)handler bytesNeeded:(size_t)bytesNeeded readToCurrentFrame:(BOOL)readToCurrentFrame unmaskBytes:(BOOL)unmaskBytes;
{
    _scanner = [scanner copy];
    _handler = [handler copy];
    _bytesNeeded = bytesNeeded;
    _readToCurrentFrame = readToCurrentFrame;
    _unmaskBytes = unmaskBytes;
    assert(_scanner || _bytesNeeded);
}


@end


@implementation SRIOConsumerPool {
    NSUInteger _poolSize;
    NSMutableArray *_bufferedConsumers;
}

- (id)initWithBufferCapacity:(NSUInteger)poolSize;
{
    self = [super init];
    if (self) {
        _poolSize = poolSize;
        _bufferedConsumers = [[NSMutableArray alloc] initWithCapacity:poolSize];
    }
    return self;
}

- (id)init
{
    // 缓存池里有8个对象
    return [self initWithBufferCapacity:8];
}

- (SRIOConsumer *)consumerWithScanner:(stream_scanner)scanner handler:(data_callback)handler bytesNeeded:(size_t)bytesNeeded readToCurrentFrame:(BOOL)readToCurrentFrame unmaskBytes:(BOOL)unmaskBytes;
{
    SRIOConsumer *consumer = nil;
    if (_bufferedConsumers.count) {
        consumer = [_bufferedConsumers lastObject];
        [_bufferedConsumers removeLastObject];
    } else {
        consumer = [[SRIOConsumer alloc] init];
    }
    
    [consumer setupWithScanner:scanner handler:handler bytesNeeded:bytesNeeded readToCurrentFrame:readToCurrentFrame unmaskBytes:unmaskBytes];
    
    return consumer;
}

- (void)returnConsumer:(SRIOConsumer *)consumer;
{
    if (_bufferedConsumers.count < _poolSize) {
        [_bufferedConsumers addObject:consumer];
    }
}

@end

// 如果把证书放在了项目里需要设置SRCertificateAdditions 属性
@implementation  NSURLRequest (SRCertificateAdditions)

- (NSArray *)SR_SSLPinnedCertificates;
{
    return [NSURLProtocol propertyForKey:@"SR_SSLPinnedCertificates" inRequest:self];
}

@end

@implementation  NSMutableURLRequest (SRCertificateAdditions)

- (NSArray *)SR_SSLPinnedCertificates;
{
    return [NSURLProtocol propertyForKey:@"SR_SSLPinnedCertificates" inRequest:self];
}

- (void)setSR_SSLPinnedCertificates:(NSArray *)SR_SSLPinnedCertificates;
{
    [NSURLProtocol setProperty:SR_SSLPinnedCertificates forKey:@"SR_SSLPinnedCertificates" inRequest:self];
}

@end

@implementation NSURL (SRWebSocket)

- (NSString *)SR_origin;
{
    NSString *scheme = [self.scheme lowercaseString];
        
    if ([scheme isEqualToString:@"wss"]) {
        scheme = @"https";
    } else if ([scheme isEqualToString:@"ws"]) {
        scheme = @"http";
    }
    
    BOOL portIsDefault = !self.port ||
                         ([scheme isEqualToString:@"http"] && self.port.integerValue == 80) ||
                         ([scheme isEqualToString:@"https"] && self.port.integerValue == 443);
    
    if (!portIsDefault) {
        return [NSString stringWithFormat:@"%@://%@:%@", scheme, self.host, self.port];
    } else {
        return [NSString stringWithFormat:@"%@://%@", scheme, self.host];
    }
}

@end

#define SR_ENABLE_LOG

static inline void SRFastLog(NSString *format, ...)  {
#ifdef SR_ENABLE_LOG
    __block va_list arg_list;
    va_start (arg_list, format);
    
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    
    va_end(arg_list);
    
    NSLog(@"[SR] %@", formattedString);
#endif
}


#ifdef HAS_ICU

static inline int32_t validate_dispatch_data_partial_string(NSData *data) {
    if ([data length] > INT32_MAX) {
        // INT32_MAX is the limit so long as this Framework is using 32 bit ints everywhere.
        return -1;
    }

    int32_t size = (int32_t)[data length];

    const void * contents = [data bytes];
    const uint8_t *str = (const uint8_t *)contents;
    
    UChar32 codepoint = 1;
    int32_t offset = 0;
    int32_t lastOffset = 0;
    while(offset < size && codepoint > 0)  {
        lastOffset = offset;
        U8_NEXT(str, offset, size, codepoint);
    }
    
    if (codepoint == -1) {
        // Check to see if the last byte is valid or whether it was just continuing
        if (!U8_IS_LEAD(str[lastOffset]) || U8_COUNT_TRAIL_BYTES(str[lastOffset]) + lastOffset < (int32_t)size) {
            
            size = -1;
        } else {
            uint8_t leadByte = str[lastOffset];
            U8_MASK_LEAD_BYTE(leadByte, U8_COUNT_TRAIL_BYTES(leadByte));
            
            for (int i = lastOffset + 1; i < offset; i++) {
                if (U8_IS_SINGLE(str[i]) || U8_IS_LEAD(str[i]) || !U8_IS_TRAIL(str[i])) {
                    size = -1;
                }
            }
            
            if (size != -1) {
                size = lastOffset;
            }
        }
    }
    
    if (size != -1 && ![[NSString alloc] initWithBytesNoCopy:(char *)[data bytes] length:size encoding:NSUTF8StringEncoding freeWhenDone:NO]) {
        size = -1;
    }
    
    return size;
}

#else

// This is a hack, and probably not optimal
static inline int32_t validate_dispatch_data_partial_string(NSData *data) {
    static const int maxCodepointSize = 3;
    
    for (int i = 0; i < maxCodepointSize; i++) {
        NSString *str = [[NSString alloc] initWithBytesNoCopy:(char *)data.bytes length:data.length - i encoding:NSUTF8StringEncoding freeWhenDone:NO];
        if (str) {
            return (int32_t)data.length - i;
        }
    }
    
    return -1;
}

#endif

/*
 常驻线程：
 即使socket连接断开，即使SRWebSocket对象销毁，这个常驻线程仍然存在。
 都不用websocket了，什么都置空了，凭什么还有一个常驻线程，不停的空转，给内存和CPU造成一定开销呢？
 考虑的是既然用户有长连接的需求，肯定断开连接甚至清空websocket对象只是一时的选择，肯定是很快会重新初始化并且重连的，这样这个常驻线程就可以得到复用，省去了重复创建，以及获取runloop等开销。
 */
static _SRRunLoopThread *networkThread = nil;
static NSRunLoop *networkRunLoop = nil;

@implementation NSRunLoop (SRWebSocket)

+ (NSRunLoop *)SR_networkRunLoop {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        networkThread = [[_SRRunLoopThread alloc] init];
        networkThread.name = @"com.squareup.SocketRocket.NetworkThread";
        [networkThread start]; //开启线程,会调用main方法
        networkRunLoop = networkThread.runLoop;
    });
    
    return networkRunLoop;
}

@end

/*
 创建子线程的目的:
 1> 开启一个runloop，让它一直跑圈,监听事件
 */
@implementation _SRRunLoopThread {
    dispatch_group_t _waitGroup;
}

@synthesize runLoop = _runLoop;

- (void)dealloc
{
    sr_dispatch_release(_waitGroup);//释放group对象
}

- (id)init
{
    self = [super init];
    if (self) {
        _waitGroup = dispatch_group_create(); //创建group对象，保证runloop一定有值
        dispatch_group_enter(_waitGroup);
    }
    return self;
}

/*
 1> 获取当前线程的runloop
 2> 创建source,添加到当前runloop中.目的：让子线程的runloop一直转圈监听
 */
- (void)main;
{
    @autoreleasepool {
        _runLoop = [NSRunLoop currentRunLoop];
        dispatch_group_leave(_waitGroup);
        
        // 往runloop里添加一个source,开启runloop
        // Add an empty run loop source to prevent runloop from spinning.
        CFRunLoopSourceContext sourceCtx = {
            .version = 0,
            .info = NULL,
            .retain = NULL,
            .release = NULL,
            .copyDescription = NULL,
            .equal = NULL,
            .hash = NULL,
            .schedule = NULL,
            .cancel = NULL,
            .perform = NULL
        };
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &sourceCtx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
        
        //runloop循环
        while ([_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
//            NSLog(@"子线程的runloop在监听....");
        }
        assert(NO); //来到这里说明,说明runloop退出。不应该来到这里
    }
}

- (NSRunLoop *)runLoop;
{
    // 用dispatch_group_wait 阻塞线程。保证_runLoop的值一定能拿到
    dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
    return _runLoop;
}

@end
