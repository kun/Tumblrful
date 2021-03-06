/**
 * @file PostAdaptor.m
 * @brief PostAdaptor implementation.
 * @author Masayuki YAMAYA
 * @date 2008-03-07
 */
#import "PostAdaptor.h"

@implementation PostAdaptor
/**
 * メニュー項目のタイトルを取得する
 *	@return タイトル
 */
+ (NSString*) titleForMenuItem
{
	return nil;
}

/**
 * メニュー項目の有効・無効を取得する
 */
+ (BOOL) enableForMenuItem
{
	return YES;
}

/**
 * initialize object
 * @param callback PostCallback オブジェクト
 * @return 初期かが完了した自分自身
 */
- (id) initWithCallback:(id<PostCallback>)callback
{
	if ((self = [super init]) != nil) {
		callback_ = [callback retain];
		private_ = NO;
	}
	return self;
}

/**
 * initialize object
 * @param callback PostCallback オブジェクト
 * @param private 非公開ポストの場合YES
 * @return 初期かが完了した自分自身
 */
- (id) initWithCallback:(id<PostCallback>)callback private:(BOOL)private
{
	if ((self = [super init]) != nil) {
		callback_ = [callback retain];
		private_ = private;
	}
	return self;
}

/**
 * dealloc
 */
- (void) dealloc
{
	if (callback_ != nil) {
		[callback_ release];
		callback_ = nil;
	}

	[super dealloc];
}


- (id<PostCallback>) callback
{
	return callback_;
}

- (void) setCallback:(id<PostCallback>)callback
{
	if (callback_ != nil) {
		[callback_ release];
	}
	callback_ = [callback retain];
}

- (BOOL) private
{
	return private_;
}

- (void) setPrivate:(BOOL)private
{
	private_ = private;
}

/**
 * callback when successed post.
 *	@param response レスポンスデータ
 */
- (void) callbackWith:(NSString*)response
{
	if (callback_ != nil) {
		[callback_ successed:response];
	}
}

/**
 * callback when failed post with NSError.
 *	@param error NSError オブジェクト
 */
- (void) callbackWithError:(NSError*)error
{
	if (callback_ != nil) {
		[callback_ failedWithError:error];
	}
}

/**
 * callback when failed post with NSException.
 *	@param error NSException オブジェクト
 */
- (void) callbackWithException:(NSException*)exception
{
	if (callback_ != nil) {
		[callback_ failedWithException:exception];
	}
}

/**
 * "Link" post 
 *	@param anchor	LinkのURLアンカー
 *	@param description Linkの説明
 *
 *	@note	サブクラスでオーバーライドしなければならない
 */
- (void) postLink:(Anchor*)anchor description:(NSString*)description
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void) postQuote:(Anchor*)anchor quote:(NSString*)quote
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void) postPhoto:(Anchor*)anchor image:(NSString*)imageURL caption:(NSString*)caption
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void) postVideo:(Anchor*)anchor embed:(NSString*)embed caption:(NSString*)caption
{
	[self doesNotRecognizeSelector:_cmd];
}

- (NSObject*) postEntry:(NSDictionary*)params
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}
@end
