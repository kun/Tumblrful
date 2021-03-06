/**
 * @file GoogleReaderDelivererContext.m
 * @brief GoogleReaderDelivererContext implementation
 * @author Masayuki YAMAYA
 * @date 2008-11-16
 */
#import "GoogleReaderDelivererContext.h"
#import "Log.h"
#import <WebKit/DOM.h>
#import <WebKit/WebView.h>

//#define V(format, ...)	Log(format, __VA_ARGS__)
#define V(format, ...)

@interface GoogleReaderDelivererContext (Private)
+ (DOMNode*) getEntryMain:(DOMHTMLDocument*)document target:(NSDictionary*)element;
- (NSString*) stringForXPath:(NSString*)xpath target:(DOMNode*)targetNode debug:(NSString*)message;
- (NSString*) getAuthor:(DOMNode*)targetNode;
- (NSString*) getTitle:(DOMNode*)targetNode;
- (NSString*) getFeedName:(DOMNode*)targetNode;
- (NSString*) getURI:(DOMNode*)targetNode;
+ (void) dumpXPathResult:(DOMXPathResult*)result withPrefix:(NSString*)prefix;
@end
@implementation GoogleReaderDelivererContext (Private)
/**
 * フィードエントリとその情報(Authorとか)を含む最も内側の div要素を得る
 * @param [in] document
 * @param [in] element
 * @return DOMNode
 */
+ (DOMNode*) getEntryMain:(DOMHTMLDocument*)document target:(NSDictionary*)element
{
	static NSString* xpath = @"ancestor-or-self::div[@class=\"entry-main\"]";

	DOMNode* targetNode = [element objectForKey:WebElementDOMNodeKey];
	if (targetNode == nil) {
		V(@"DOMNode not found: %@", element);
		return nil;
	}

	V(@"getEntryMain: target: %@", SafetyDescription(targetNode));
	DOMXPathResult* result;
	result = [document evaluate:xpath
					contextNode:targetNode
					   resolver:nil /* nil for HTML document */
						   type:DOM_ANY_TYPE
						inResult:nil];

	[self dumpXPathResult:result withPrefix:@"getEntryMain"];

	if (result != nil) {
		if (![result invalidIteratorState]) {
			DOMNode* node;
			for (node = [result iterateNext]; node != nil; node = [result iterateNext]) {
				V(@"node: %@ id:%@", [node description], [((DOMHTMLDivElement*)node) idName]);
				return node; /* 先頭のDOMノードでOK(1ノードしか選択していないハズ) */
			}
		}
	}
	V(@"Failed XPath for targetNode: %@", [targetNode description]);
	return nil;
}

/**
 * stringForXPath.
 * @param [in] xpath
 * @param [in] targetNode
 * @param [in] message
 * @return NSString*
 *
 * TODO: なんでこのメソッド必要なんだっけ？
 */
- (NSString*) stringForXPath:(NSString*)xpath
					  target:(DOMNode*)targetNode
					   debug:(NSString*)message
{
	V(@"%@: targetNode: %@", message, SafetyDescription(targetNode));
	if ([targetNode respondsToSelector:@selector(idName)]) {
		V(@"%@: targetNode's id: %@", message, [targetNode performSelector:@selector(idName)]);
	}

	@try {
		DOMXPathResult* result;
		result = [self evaluateToDocument:xpath
							  contextNode:targetNode
									 type:DOM_STRING_TYPE
								 inResult:nil];

		[GoogleReaderDelivererContext dumpXPathResult:result withPrefix:message];

		if (result != nil && [result resultType] == DOM_STRING_TYPE) {
			return [result stringValue];
		}
	}
	@catch (NSException* e) {
		V(@"Catch exception: %@", [e description]);
	}

	return [[[NSString alloc] init] autorelease];
}

/**
 * getAuthor
 *	フィードエントリの作者を得る
 * @param [in] targetNode
 * @return NSString*
 */
- (NSString*) getAuthor:(DOMNode*)targetNode
{
	static NSString* xpath = @"./div[@class=\"entry-author\"]/*[@class=\"entry-author-name\"]/text()";

	NSString* author = nil;
	
	author = [self stringForXPath:xpath target:targetNode debug:@"getAuthor"];
	if (author != nil && [author length] > 3) {
		return author;
	}
	return [[[NSString alloc] init] autorelease];
}

/**
 * getTitle
 *	フィードエントリのタイトルを得る
 * @param [in] targetNode
 * @return NSString*
 */
- (NSString*) getTitle:(DOMNode*)targetNode
{
	static NSString* xpath = @"./h2[@class=\"entry-title\"]//a/text()";

	NSString* title = nil;
	title = [self stringForXPath:xpath target:targetNode debug:@"getTitle"];
	if (title != nil) {
		return title;
	}

	return [[[NSString alloc] initWithString:@"no title"] autorelease];
}

/**
 * getFeedName
 *	フィード名(サイト名)を得る
 */
- (NSString*) getFeedName:(DOMNode*)targetNode
{
	static NSString* xpath = @"./div[@class=\"entry-author\"]//a/text()";

	NSString* title = nil;
	title = [self stringForXPath:xpath target:targetNode debug:@"getFeedName"];
	if (title != nil) {
		return title;
	}

	return [[[NSString alloc] initWithString:@"no feedname"] autorelease];
}

/**
 * getURI
 *	元記事へのURIを得る
 */
- (NSString*) getURI:(DOMNode*)targetNode
{
	static NSString* xpath = @"./h2[@class=\"entry-title\"]//a/@href";

	@try {
		DOMXPathResult* result;
		result = [self evaluateToDocument:xpath
							  contextNode:targetNode
									 type:DOM_ANY_TYPE
								 inResult:nil];

		[GoogleReaderDelivererContext dumpXPathResult:result withPrefix:@"getURI"];

		if (result != nil && [result resultType] == DOM_UNORDERED_NODE_ITERATOR_TYPE) {
			if (![result invalidIteratorState]) {
				DOMNode* node = nil;
				for (node = [result iterateNext]; node != nil; node = [result iterateNext]) {
					V(@"1st node: name: %@ type: %d value: %@ textContent: %@",
							[node nodeName],
							[node nodeType],
							[node nodeValue],
							[node textContent]);
					/* s/[?&;](fr?(om)?|track|ref|FM)=(r(ss(all)?|df)|atom)([&;].*)?//g */
					return [node textContent];
				}
			}
		}
	}
	@catch (NSException* e) {
		V(@"Catch exception: %@", [e description]);
	}

	return [[[NSString alloc] init] autorelease];
}

/**
 *
 */
+ (void) dumpXPathResult:(DOMXPathResult*)result withPrefix:(NSString*)prefix
{
#define ToTypeName(t) \
					(t == DOM_NUMBER_TYPE ? @"NUMBER" : \
					 t == DOM_STRING_TYPE ? @"STRING" : \
					 t == DOM_BOOLEAN_TYPE ? @"BOOLEAN" : \
					 t == DOM_UNORDERED_NODE_ITERATOR_TYPE ? @"UNORDERED_NODE_ITERATOR" : \
					 t == DOM_ORDERED_NODE_ITERATOR_TYPE ? @"ORDERED_NODE_ITERATOR" : \
					 t == DOM_UNORDERED_NODE_SNAPSHOT_TYPE ? @"UNORDERED_NODE_SNAPSHOT" : \
					 t == DOM_ORDERED_NODE_SNAPSHOT_TYPE ? @"ORDERED_NODE_SNAPSHOT" : \
					 t == DOM_ANY_UNORDERED_NODE_TYPE ? @"ANY_UNORDERED_NODE" : \
					 t == DOM_FIRST_ORDERED_NODE_TYPE ? @"FIRST_ORDERED_NODE" : \
					 t == DOM_ANY_TYPE ? @"ANY" : @"Unknown?")

	@try {
		if (result != nil) {
			V(@"XPath: %@ {", prefix);
			V(@"  description: %@", [result description]);
			V(@"  resultType: %@", ToTypeName([result resultType]));
			switch ([result resultType]) {
			case DOM_NUMBER_TYPE:
				V(@"  numberValue: %f", [result numberValue]);
				break;
			case DOM_STRING_TYPE:
				V(@"  stringValue: %@", [result stringValue]);
				break;
			case DOM_BOOLEAN_TYPE:
				V(@"  booleanValue: %d", [result booleanValue]);
				break;
			case DOM_ORDERED_NODE_SNAPSHOT_TYPE:
			case DOM_UNORDERED_NODE_SNAPSHOT_TYPE:
				V(@"  snapshotLength: %d", [result snapshotLength]);
				V(@"  snapshotItem[0]: %@", [[result snapshotItem:0] description]);
				break;
			case DOM_ORDERED_NODE_ITERATOR_TYPE:
			case DOM_UNORDERED_NODE_ITERATOR_TYPE:
				V(@"  %@s invalidIteratorState: %d", @"NODE_ITERATOR", [result invalidIteratorState]);
				break;
			case DOM_FIRST_ORDERED_NODE_TYPE:
				V(@"  %@ invalidIteratorState: %d", @"FIRST_ORDERED_NODE", [result invalidIteratorState]);
				break;
			default:
				V(@"  resultType was invalid%@", @"!");
			}
			V(@"%@", @"}");
		}
	}
	@catch (NSException* e) {
		V(@"Catch exception: %@", [e description]);
	}
}
@end

@implementation GoogleReaderDelivererContext : DelivererContext
/**
 * 自分が処理すべき HTML ドキュメントかどうかを判定する
 * @param [in] document URL を含む DOM ドキュメント
 * @param [in] targetElement 選択している要素
 * @return 処理すべき URL の場合 true
 */
+ (BOOL) match:(DOMHTMLDocument*)document target:(NSDictionary*)targetElement
{
	NSURL* u = [NSURL URLWithString:[document URL]];
	if (u != nil) {
		NSString* host = [u host];
		if ([host isEqualToString:@"www.google.com"]) {
			NSString* path = [u path];
			if ([path hasPrefix:@"/reader/view"]) {
				return [self getEntryMain:document target:targetElement] != nil;
			}
		}
	}
	return NO;
}

/**
 * 自分が処理すべき HTML ドキュメントかどうかを判定する
 * @param [in] document URL を含む DOM ドキュメント
 * @param [in] wso Window スクリプトオブジェクト
 * @return 処理すべき HTMLドキュメントの場合、ポスト対象となる要素
 */
+ (DOMHTMLElement*) matchForAutoDetection:(DOMHTMLDocument*)document windowScriptObject:(WebScriptObject*)wso;
{
	DOMHTMLElement* element = nil;

	NSURL* url = [NSURL URLWithString:[document URL]];
	if (url != nil) {
		NSString* host = [url host];
		if ([host isEqualToString:@"www.google.com"]) {
			NSString* path = [url path];
			if ([path hasPrefix:@"/reader/view"]) {
				NSArray* expressions = [NSArray arrayWithObjects:
					  @"//div[@id=\"current-entry\"]//div[@class=\"item-body\"]//img"
					, @"//div[@id=\"current-entry\"]//div[@class=\"item-body\"]"
					, nil];
				element = [DelivererContext evaluate:expressions
											document:document
										 contextNode:document];
			}
		}
	}

	return element;
}

/**
 * オブジェクトの初期化
 * @param [in] document URL を含む DOM ドキュメント
 * @param [in] targetElement 選択している要素
 * @return 自身のオブジェクト
 */
- (id) initWithDocument:(DOMHTMLDocument*)document target:(NSDictionary*)targetElement
{
	if ((self = [super initWithDocument:document target:targetElement]) != nil) {
		DOMNode* target = [GoogleReaderDelivererContext getEntryMain:document target:targetElement];
		if (target != nil) {
			author_ = [[self getAuthor:target] retain];
			title_ = [[self getTitle:target] retain];
			feedName_ = [[self getFeedName:target] retain];
			uri_ = [[self getURI:target] retain];
		}
		else {
			/* 通常はあり得ない - match で同じ事を実行して成功しているはずだから*/
			V(@"Failed getEntryMain. element: %@", SafetyDescription(targetElement));
		}
	}
	return self;
}

/**
 * オブジェクトの解放
 */
- (void) dealloc
{
	if (author_ != nil) [author_ release];
	if (title_ != nil) [title_ release];
	if (feedName_ != nil) [feedName_ release];
	if (uri_ != nil) [uri_ release];

	[super dealloc];
}

/**
 * フィード名とフィードタイトルを連結したものをドキュメントタイトルとする
 */
- (NSString*) documentTitle
{
	NSMutableString* title = [[[NSMutableString alloc] initWithString:feedName_] autorelease];

	if (title_ != nil && [title_ length] > 0) {
		[title appendFormat:@" - %@", title_];
	}

	return title;
}

/**
 *
 */
- (NSString*) documentURL
{
	return uri_;
}

/**
 * メニュータイトル(の部分)を返す
 */
- (NSString*) menuTitle
{
	return @" - Google Reader";
}
@end
