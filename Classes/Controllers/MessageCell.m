#import <QuartzCore/QuartzCore.h>
#import "TwitterFonAppDelegate.h"
#import "MessageCell.h"
#import "ColorUtils.h"
#import "StringUtil.h"
#import "REString.h"
#import "TimeUtils.h"

static UIImage* sFavorite = nil;
static UIImage* sFavorited = nil;

@implementation MessageCell

@synthesize message;
@synthesize profileImage;
@synthesize inEditing;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	[super initWithFrame:frame reuseIdentifier:reuseIdentifier];

    cellView = [[[MessageCellView alloc] initWithFrame:CGRectZero] autorelease];
    [self.contentView addSubview:cellView];
    
    profileImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [profileImage addTarget:self action:@selector(didTouchProfileImage:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:profileImage];

    inEditing = false;

    self.target = self;
    self.accessoryAction = @selector(didTouchLinkButton:);
    
	return self;
}

- (void)dealloc
{
    [super dealloc];
}    

- (void)updateImage:(UIImage*)image
{
    if (cellType != MSG_CELL_TYPE_USER) {
        [profileImage setImage:image forState:UIControlStateNormal];
        [profileImage setNeedsDisplay];
    }
}

- (void)didTouchLinkButton:(id)sender
{
    TwitterFonAppDelegate *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
    [appDelegate openLinksViewController:message];
}

- (void)didTouchProfileImage:(id)sender
{
    TwitterFonAppDelegate *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
    
    if (cellType == MSG_CELL_TYPE_USER) {
        [self toggleSpinner:true];
        [appDelegate toggleFavorite:message];
    }
    else {
        PostViewController* postView = appDelegate.postView;
        if (message.type == MSG_TYPE_MESSAGES || message.type == MSG_TYPE_SENT) {
            [postView editDirectMessage:message.user.screenName];
        }
        else {
            [postView inReplyTo:message];
        }
    }
}

- (void)update:(MessageCellType)aType
{
    cellType            = aType;
    cellView.message    = message;
    
    if (cellType != MSG_CELL_TYPE_USER) {
        message.user.imageContainer = self;
        TwitterFonAppDelegate *appDelegate = (TwitterFonAppDelegate*)[UIApplication sharedApplication].delegate;
        [profileImage setImage:[appDelegate.imageStore getProfileImage:message.user isLarge:false] forState:UIControlStateNormal];
    }
    
    self.contentView.backgroundColor = (message.unread) ? [UIColor cellColorForTab:message.type] : [UIColor whiteColor];

    if (cellType != MSG_CELL_TYPE_USER && message.hasReply) {
        if (message.type == MSG_TYPE_FRIENDS || message.type == MSG_TYPE_SEARCH_RESULT) {
            self.contentView.backgroundColor = [UIColor cellColorForTab:TAB_REPLIES];
        }
    }
    
    
    self.selectionStyle = (cellType == MSG_CELL_TYPE_USER) ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
    self.accessoryType = message.accessoryType;

    if (cellType == MSG_CELL_TYPE_USER) {
        self.contentView.backgroundColor = [UIColor whiteColor];
        cellView.frame = CGRectMake(USER_CELL_LEFT, 0, USER_CELL_WIDTH, message.cellHeight - 1);
        
        if (message.favorited) {
            [profileImage setImage:[MessageCell favoritedImage] forState:UIControlStateNormal];
        }
        else {
            [profileImage setImage:[MessageCell favoriteImage] forState:UIControlStateNormal];
        }
    }
    else {
        cellView.frame = CGRectMake(LEFT, 0, CELL_WIDTH, message.cellHeight - 1);
    }
    
    if (cellType == MSG_CELL_TYPE_USER && inEditing) {
        cellView.frame = CGRectOffset(cellView.frame, -32, 0);
        profileImage.hidden = true;
    }
    else {
        profileImage.hidden = false;
    }
}

- (void)layoutSubviews
{
	[super layoutSubviews];

    self.backgroundColor = self.contentView.backgroundColor;
    cellView.backgroundColor = self.contentView.backgroundColor;
    
    if (message.cellType == MSG_CELL_TYPE_USER) {
        profileImage.frame = CGRectMake(2, 0, 38, message.cellHeight);
    }
    else {
        profileImage.frame = CGRectMake(IMAGE_PADDING, (message.cellHeight - 48 - 1)/2, IMAGE_WIDTH, 48);
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (cellType == MSG_CELL_TYPE_USER && animated && (editing || inEditing)) {

        profileImage.hidden = editing;
        [UIView beginAnimations:nil context:nil];
        int x = (editing) ? 10 : 42;
        cellView.frame = CGRectMake(x, cellView.frame.origin.y, cellView.frame.size.width, cellView.frame.size.height);
        [UIView commitAnimations];
        
        inEditing = editing;
    }

}

- (void)toggleFavorite:(BOOL)favorited
{
    if (favorited) {
        [profileImage setImage:[MessageCell favoritedImage] forState:UIControlStateNormal];
    }
    else {
        [profileImage setImage:[MessageCell favoriteImage] forState:UIControlStateNormal];
    }    
    
    [self toggleSpinner:false];
    
    CATransition *animation = [CATransition animation];
    [animation setType:kCATransitionFade];
    [animation setDuration:0.2];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [profileImage.layer addAnimation:animation forKey:@"favoriteButton"];
}

- (void)toggleSpinner:(BOOL)animation
{
    if (spinner == nil) {
        spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
        spinner.frame = CGRectMake(11, (message.cellHeight - 20)/2, 20, 20);
        spinner.hidesWhenStopped = YES;
        [self.contentView addSubview:spinner];
    }

    if (animation) {
        [spinner startAnimating];
        profileImage.hidden = true;
    }
    else {
        [spinner stopAnimating];
        profileImage.hidden = false;
    }
}

+ (UIImage*) favoriteImage
{
    if (sFavorite == nil) {
        sFavorite = [[UIImage imageNamed:@"favorite.png"] retain];
    }
    return sFavorite;
}

+ (UIImage*) favoritedImage
{
    if (sFavorited == nil) {
        sFavorited = [[UIImage imageNamed:@"favorited.png"] retain];
    }
    return sFavorited;
}

@end
