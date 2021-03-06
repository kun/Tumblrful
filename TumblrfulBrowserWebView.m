/**
 * @file TumblrfulBrowserWebView.m
 * @brief TumblrfulBrowserWebView implementation
 * @author Masayuki YAMAYA
 * @date 2008-03-03
 */
// /System/Library/Frameworks/WebKit.framework/Headers/DOMNode.h
// /System/Library/Frameworks/WebKit.framework/Headers/WebView.h
#import "TumblrfulBrowserWebView.h"
#import "QuoteDeliverer.h"
#import "LinkDeliverer.h"
#import "ReblogDeliverer.h"
#import "LDRReblogDeliverer.h"
#import "GoogleReaderReblogDeliverer.h"
#import "PhotoDeliverer.h"
#import "FlickrPhotoDeliverer.h"
#import "VideoDeliverer.h"
#import "VimeoVideoDeliverer.h"
#import "SlideShareVideoDeliverer.h"
#import "TumblrPost.h"
#import "GrowlSupport.h"
#import "PostAdaptorCollection.h"
#import "TumblrPostAdaptor.h"
#import "DeliciousPostAdaptor.h"
#import "UmesuePostAdaptor.h"
#import "DebugLog.h"
#import "GoogleReaderDelivererContext.h"
#import "LDRDelivererContext.h"
#import <WebKit/DOMHTML.h>

/* POST先のサービスを識別するマスク値 */
static const NSUInteger POST_MASK_NONE = 0x0;
static const NSUInteger POST_MASK_TUMBLR = 0x1;
static const NSUInteger POST_MASK_UMESUE = 0x2;
static const NSUInteger POST_MASK_DELICIOUS = 0x4;
static const NSUInteger POST_MASK_ALL = 0x7;

@implementation WebView (TumblrfulBrowserWebView)
/*!
    @method webView:contextMenuItemsForElement:defaultMenuItems:
    @abstract Returns the menu items to display in an element's contextual menu.
    @param sender The WebView sending the delegate method.
    @param element A dictionary representation of the clicked element.
    @param defaultMenuItems An array of default NSMenuItems to include in all contextual menus.
    @result An array of NSMenuItems to include in the contextual menu.
*/
- (NSArray*) webView_SwizzledByTumblrful:(WebView*)sender contextMenuItemsForElement:(NSDictionary*)element defaultMenuItems:(NSArray*)defaultMenuItems;
{
	// オリジナルのメソッドを呼ぶ
	NSArray* original =  [self webView_SwizzledByTumblrful:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
	return [self buildMenu:[original mutableCopy] element:element]; // add Tumblrful to original menu
}

/**
 * Deliverer の class を singleton な array にしまっておく
 *
 * @return array of Deliverers.
 */
- (NSArray*) sharedDelivererClasses
{
	static NSMutableArray* classes = nil;

	if (classes == nil) {
		/* setup PostAdaptorCollection */
		[PostAdaptorCollection add:[TumblrPostAdaptor class]];
		[PostAdaptorCollection add:[UmesuePostAdaptor class]];
		[PostAdaptorCollection add:[DeliciousPostAdaptor class]];

		classes = [NSMutableArray arrayWithObjects:
			  [GoogleReaderReblogDeliverer class]
			, [LDRReblogDeliverer class]
			, [ReblogDeliverer class]
			, [FlickrPhotoDeliverer class]
			, [PhotoDeliverer class]
			, [QuoteDeliverer class]
			, [VimeoVideoDeliverer class]
			, [SlideShareVideoDeliverer class]
			, [VideoDeliverer class]
			, [LinkDeliverer class]
			, nil];
		[classes retain]; // must
	}
	return classes;
}

/**
 * validate account
 *
 * @return true is valid account, other than false.
 */
- (BOOL) validateAccount
{
	NSString* mail = [TumblrPost username];
	NSString* pass = [TumblrPost password];

	return (mail != nil) && ([mail length] > 0) && (pass != nil) && ([pass length] > 0);
}

/**
 * buildMenu
 *	コンテキストメニューに独自の要素を追加する。
 * @param menu オリジナルの NSMenuItem の配列
 * @param element クリックしている要素
 * @return NSMenuItem の配列
 */
- (NSArray*) buildMenu:(NSMutableArray*)menu element:(NSDictionary*)element
{
	if (![self validateAccount]) {
		[GrowlSupport notify:@"Tumblrful" description:@"Email or Password not entered."];
		return menu;
	}

	id<Deliverer> deliverer = nil;
	NSEnumerator* classEnumerator = [[self sharedDelivererClasses] objectEnumerator];
	Class class;
	while (class = [classEnumerator nextObject]) {
		deliverer = [class create:(DOMHTMLDocument*)[self mainFrameDocument] element:element];
		if (deliverer != nil) {
			int i = 0;
			NSArray* menuItems = [(DelivererBase*)deliverer createMenuItems];
			NSEnumerator* menuEnumerator = [menuItems objectEnumerator];
			NSMenuItem* menuItem;
			while ((menuItem = [menuEnumerator nextObject]) != nil) {
				[menu insertObject:menuItem atIndex:i];
				i++;
			}
			[menu insertObject:[NSMenuItem separatorItem] atIndex:i];
			return menu;
		}
	}

	/* error process */
	[GrowlSupport notify:@"Tumblrful" description:@"Error - Could not detect type of post"];
	return menu;
}

/**
 * aciotn: セレクタを発動する
 * @param [in] target ポスト対象要素
 * @param [in] document 評価対象となる DOMドキュメント
 * @param [in] endpoint ポスト先を示すビット値
 */
- (BOOL) invokeAction:(DOMHTMLElement*)target document:(DOMHTMLDocument*)document endpoint:(NSUInteger)endpoint
{
	if (target == nil) {
		return NO;
	}

	SEL sel = @selector(actionWithMask:);
	Class photoClass = [PhotoDeliverer class];
	Class reblogClass = [ReblogDeliverer class];

	@try {
		// 対象要素が Imageなら WebElementImageURLKey で ImageのソースURLを抽出する
		NSMutableDictionary* elements = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			  target
			, WebElementDOMNodeKey
			, nil];
		if ([target isKindOfClass:[DOMHTMLImageElement class]]) {
			[elements setObject:[(DOMHTMLImageElement*)target src] forKey:WebElementImageURLKey];
		}

		for (Class clazz in [[self sharedDelivererClasses] objectEnumerator]) {
			id<Deliverer> maybeDeliver = [clazz create:document element:elements];
			if (maybeDeliver == nil) {
				continue;
			}

			// Deliverer が Photo か Reblog の場合のみキー入力によるポストを有効にするものとする
			// Quote はセレクションが出来ないと不可だし、Link は使用頻度が低いので
			DelivererBase* deliverer = (DelivererBase*) maybeDeliver;
			if ([deliverer respondsToSelector:sel] && ([deliverer isKindOfClass:photoClass] || [deliverer isKindOfClass:reblogClass])) {
				NSBeep();

				// セレクタに渡す引数を作成して実行する
				NSArray* param = [NSArray arrayWithObjects:
					  self
					, [NSNumber numberWithUnsignedInteger:endpoint]
					, nil];
				[deliverer performSelectorOnMainThread:sel withObject:param waitUntilDone:YES];

				[deliverer release];
				return YES;
			}
		}
	}
	@catch (NSException* e) {
		D0([e description]);
	}

	return NO;
}

/**
 * ポスト先サービス(エンドポイント)を示すビット値を組み立てる
 * @param [in] event NSEvent object for Event.
 * @return ビット値
 */
- (NSUInteger) endpointByKeyPress:(NSEvent*)event
{
	NSUInteger endpoint = POST_MASK_NONE;

	// Ctrlキーが押されたかをチェック(オートリピート時は無視)
	if ([event type] == NSKeyDown && ([event modifierFlags] & NSControlKeyMask) == NSControlKeyMask && ![event isARepeat]) {
		// キー毎にビットマスクを決める
		NSString* c = [event charactersIgnoringModifiers];
		if ([c isEqualToString:@"t"]) {
			// Tumblr にポストしたら無条件に Umesue にもポストする
			endpoint = POST_MASK_TUMBLR | POST_MASK_UMESUE;
		}
		else if ([c isEqualToString:@"u"]) {
			// Umesue はそれだけ
			endpoint = POST_MASK_UMESUE;
		}
		else if ([c isEqualToString:@"d"]) {
			// delicious もそれだけ
			endpoint = POST_MASK_DELICIOUS;
		}
	}

	return endpoint;
}

/**
 * @brief performKeyEquivalent
 *	このメソッドが呼ばれるのはjavascriptで食われていないキーの時だけみたい。
 *	このメソッドはとりあえずで作ったのでクラスの責務を逸脱しているし、コンテ
 *	キストメニューとの統一も考えてない。が、使い心地が良いのでそのままにして
 *	ある。
 *	メソッド長いし。
 * @param event NSEvent object for Event.
 * @return イベントに応答した場合 YES。
 */
- (BOOL)performKeyEquivalent_SwizzledByTumblrful:(NSEvent*)event
{
	// キー入力に対応するエンドポイントを得る。
	NSUInteger endpoint = [self endpointByKeyPress:event];
	if ((endpoint & POST_MASK_ALL) == 0) {
		// 無ければオリジナルのメソッドを呼び出して終わり
		return [self performKeyEquivalent_SwizzledByTumblrful:event];
	}

	// このビューに関する HTMLドキュメントの URL を得る
	DOMHTMLDocument* document = (DOMHTMLDocument*)[self mainFrameDocument];
	if (document == nil) {
		// 無ければオリジナルのメソッドを呼び出して終わり
		return [self performKeyEquivalent_SwizzledByTumblrful:event];
	}

	BOOL processed = NO;

	//FIXME: DeliverBase にも同じ配列を生成していて無駄
	NSArray* contexts = [NSArray arrayWithObjects:
		  [GoogleReaderDelivererContext class]
		, [LDRDelivererContext class]
		, nil];
	for (Class c in contexts) {
		// 処理すべき HTMLドキュメントかどうかを判定させる
		DOMHTMLElement* element = [c matchForAutoDetection:document
										windowScriptObject:[self windowScriptObject]];

		// アクションを実行を試みる
		processed = [self invokeAction:element document:document endpoint:endpoint];

		// 実行できたら処理終了
		if (processed) {
			break;
		}
	}
	if (!processed) {
		// 無ければ親オブジェクトに委譲して終わり
		processed = [self performKeyEquivalent_SwizzledByTumblrful:event];
	}
	return processed;
}
@end
