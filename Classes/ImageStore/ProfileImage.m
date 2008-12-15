#import "ProfileImage.h"
#import "ImageDownloader.h"
#import "DBConnection.h"

UIImage *sProfileImage = nil;
UIImage *sProfileImageSmall = nil;

//sqlite3 statements
static sqlite3_stmt *insert_statement = nil;
static sqlite3_stmt *select_statement = nil;

@interface ProfileImage (Private)
- (void)requestImage;
+ (UIImage*)defaultProfileImage:(BOOL)bigger;
@end

@interface ProfileImage (ProfileImagePrivate)
- (BOOL)resizeImage;
- (void)convertImage;
@end
@implementation ProfileImage

@synthesize image;

- (ProfileImage*)initWithURL:(NSString*)aUrl delegate:(id)aDelegate
{
	self = [super init];
    url  = [aUrl copy];
    delegate = aDelegate;
    database = [DBConnection getSharedDatabase];

    if (select_statement == nil) {
        static const char *sql = "SELECT image FROM images WHERE url=?";
        if (sqlite3_prepare_v2(database, sql, -1, &select_statement, NULL) != SQLITE_OK) {
            NSLog(@"%s", sqlite3_errmsg(database));
            NSAssert1(0, @"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg(database));
        }
    }

    // Note that the parameters are numbered from 1, not from 0.
    sqlite3_bind_text(select_statement, 1, [url UTF8String], -1, SQLITE_TRANSIENT);    
    if (sqlite3_step(select_statement) == SQLITE_ROW) {
        // Restore image from Database
        int length = sqlite3_column_bytes(select_statement, 0);
        NSData *data = [NSData dataWithBytes:sqlite3_column_blob(select_statement, 0) length:length];
        image = [[UIImage imageWithData:data] retain];
        [self resizeImage];
        [self convertImage];
    } else {
        
        NSRange r = [url rangeOfString:@"_bigger."];
        image = [ProfileImage defaultProfileImage:(r.location != NSNotFound) ? true : false];
        [self requestImage];
    }
    sqlite3_reset(select_statement);

	return self;
}

- (void)insertImage:(NSData*)buf
{
    
    if (insert_statement == nil) {
        static const char *sql = "REPLACE INTO images VALUES(?, ?, DATETIME('now'))";
        if (sqlite3_prepare_v2(database, sql, -1, &insert_statement, NULL) != SQLITE_OK) {
            NSAssert1(0, @"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg(database));
        }
    }
    sqlite3_bind_text(insert_statement, 1, [url UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_blob(insert_statement, 2, buf.bytes, buf.length, SQLITE_TRANSIENT);

    int success = sqlite3_step(insert_statement);
    sqlite3_reset(insert_statement);
    
    if (success != SQLITE_DONE) {
        NSAssert2(0, @"Error: failed to execute SQL command in %@ with message '%s'.", NSStringFromSelector(_cmd), sqlite3_errmsg(database));
    }
}

- (void)requestImage
{
    [delegate retain];
    ImageDownloader* dl = [[ImageDownloader alloc] initWithDelegate:self];
    [dl get:url];
}

- (BOOL)resizeImage
{
    // Resize image if needed.
    float width  = image.size.width;
    float height = image.size.height;
    // fail safe
    if (width == 0 || height == 0) return false;
    
    float scale;
    
    NSRange r = [url rangeOfString:@"_bigger."];
    float numPixels = (r.location != NSNotFound) ? 73.0 : 48.0;
    
    if (width > numPixels || height > numPixels) {
        if (width > height) {
            scale = numPixels / height;
            width *= scale;
            height = numPixels;
        }
        else {
            scale = numPixels / width;
            height *= scale;
            width = numPixels;
        }
        
        NSLog(@"Resize image %.0fx%.0f -> (%.0f,%.0f)x(%.0f,%.0f)", image.size.width, image.size.height, 
              0 - (width - numPixels) / 2, 0 - (height - numPixels) / 2, width, height);
        
        UIGraphicsBeginImageContext(CGSizeMake(numPixels, numPixels));
        [image drawInRect:CGRectMake(0 - (width - numPixels) / 2, 0 - (height - numPixels) / 2, width, height)];
        [image release];
        image = UIGraphicsGetImageFromCurrentImageContext();
        [image retain];
        UIGraphicsEndImageContext();
        NSData *jpeg = UIImageJPEGRepresentation(image, 0.8);
        [self insertImage:jpeg];
        return true;
    }
    return false;
}

- (void)convertImage
{
    NSRange r = [url rangeOfString:@"_bigger."];
    float numPixels = (r.location != NSNotFound) ? 73.0 : 48.0;
    float radius = (r.location != NSNotFound) ? 8.0 : 4.0;

    UIGraphicsBeginImageContext(CGSizeMake(numPixels, numPixels));
    CGContextRef c = UIGraphicsGetCurrentContext();

    CGContextBeginPath(c);
    CGContextMoveToPoint  (c, numPixels, numPixels/2);
    CGContextAddArcToPoint(c, numPixels, numPixels, numPixels/2, numPixels,   radius);
    CGContextAddArcToPoint(c, 0,         numPixels, 0,           numPixels/2, radius);
    CGContextAddArcToPoint(c, 0,         0,         numPixels/2, 0,           radius);
    CGContextAddArcToPoint(c, numPixels, 0,         numPixels,   numPixels/2, radius);
    CGContextClosePath(c);

    CGContextClip(c);

    [image drawAtPoint:CGPointZero];
    [image release];
    image = UIGraphicsGetImageFromCurrentImageContext();
    [image retain];
    UIGraphicsEndImageContext();
}


- (void)imageDownloaderDidSucceed:(ImageDownloader*)sender
{
	image = [[UIImage imageWithData:sender.buf] retain];

    if (!image) {
        [delegate release];
        delegate = nil;
        return;
    }

    if ([self resizeImage] == false)  {
        // Insert to DB
        [self insertImage:sender.buf];
    }
    [self convertImage];
    
    if ([delegate respondsToSelector:@selector(profileImageDidGetNewImage:)]) {
        [delegate performSelector:@selector(profileImageDidGetNewImage:) withObject:image];
    }
    [delegate release];
    delegate = nil;
}

- (void)imageDownloaderDidFail:(ImageDownloader*)sender error:(NSError*)error
{
    [delegate release];
    delegate = nil;
}

- (void)dealloc
{
    if (delegate) {
        [delegate release];
    }
    [url release];
    [image release];
	[super dealloc];
}


+(UIImage*)defaultProfileImage:(BOOL)bigger
{
    if (bigger) {
        if (sProfileImage == nil) {
            sProfileImage = [[UIImage imageNamed:@"profileImage.png"] retain];
        }
        return sProfileImage;
    }
    else {
        if (sProfileImageSmall == nil) {
            sProfileImageSmall = [[UIImage imageNamed:@"profileImageSmall.png"] retain];
        }
        return sProfileImageSmall;
    }
}
@end
