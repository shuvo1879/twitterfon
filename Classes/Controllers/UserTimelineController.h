//
//  UserTimelineController.h
//  TwitterFon
//
//  Created by kaz on 8/20/08.
//  Copyright 2008 naan studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserCell.h"
#import "LoadCell.h"
#import "Message.h"
#import "Timeline.h"
#import "TwitterClient.h"

@class TimelineViewDataSource;

@interface UserTimelineController : UITableViewController {
    UserCell*               userCell;
    User*                   user;
    NSString*               screenName;
    LoadCell*               loadCell;
    Timeline*               timeline;
    int                     indexOfLoadCell;
    int                     page;
    NSMutableArray*         deletedMessage;
    TwitterClient*          twitterClient;
    BOOL                    didCheckFriendship;
    
    CGPoint                 contentOffset;
}

- (void)setUser:(User *)user;
- (void)loadUserTimeline:(NSString*)screenName;

@end
