//
//  RendezvousBrowserController.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on Wed Feb 25 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "RendezvousBrowserController.h"
#import "TCMRendezvousBrowser.h"


@interface RendezvousBrowserController (RendezvousBrowserControllerPrivateAdditions)

- (int)TCM_indexOfItemWithUserID:(NSString *)aUserID;

@end

#pragma mark -

@implementation RendezvousBrowserController
- (id)init {
    if ((self=[super initWithWindowNibName:@"RendezvousBrowser"])) {
        I_data=[NSMutableArray new];
        I_browser=[[TCMRendezvousBrowser alloc] initWithServiceType:@"_emac._tcp." domain:@""];
        [I_browser setDelegate:self];
        [I_browser startSearch];
        I_foundUserIDs=[NSMutableSet new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidChangeVisibility:) name:TCMMMPresenceManagerUserVisibilityDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidChangeAnnouncedDocuments:) name:TCMMMPresenceManagerUserSessionsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [I_foundUserIDs release];
    [I_data release];
    [super dealloc];
}

- (void)windowDidLoad {
    [[self window] setFrameAutosaveName:@"RendezvousBrowser"];
    TCMMMUser *me=[TCMMMUserManager me];
    [O_myNameTextField setStringValue:[me name]];
    [O_imageView setImage:[[me properties] objectForKey:@"Image"]];
    [((NSPanel *)[self window]) setFloatingPanel:NO];
    [[self window] setHidesOnDeactivate:NO];
    
    NSRect frame=[[O_scrollView contentView] frame];
    O_browserListView=[[TCMMMBrowserListView alloc] initWithFrame:frame];
    [O_scrollView setBorderType:NSBezelBorder];
    [O_browserListView setDataSource:self];
    [O_browserListView   setDelegate:self];
    [O_browserListView setTarget:self];
    [O_browserListView setDoubleAction:@selector(joinSession:)];
    [O_scrollView setHasVerticalScroller:YES];
    [[O_scrollView verticalScroller] setControlSize:NSSmallControlSize];
    [O_scrollView setDocumentView:O_browserListView];
    [O_browserListView noteEnclosingScrollView];
}

- (IBAction)setVisibilityByPopUpButton:(id)aSender {
    [[TCMMMPresenceManager sharedInstance] setVisible:([aSender indexOfSelectedItem]==0)];
}

- (IBAction)joinSession:(id)aSender
{
    NSLog(@"joinSession in row: %d", [aSender clickedRow]);
}

#pragma mark -
#pragma mark ### TCMRendezvousBrowser Delegate ###
- (void)rendezvousBrowserWillSearch:(TCMRendezvousBrowser *)aBrowser {

}
- (void)rendezvousBrowserDidStopSearch:(TCMRendezvousBrowser *)aBrowser {

}
- (void)rendezvousBrowser:(TCMRendezvousBrowser *)aBrowser didNotSearch:(NSError *)anError {
    NSLog(@"Mist: %@",anError);
}

- (void)rendezvousBrowser:(TCMRendezvousBrowser *)aBrowser didFindService:(NSNetService *)aNetService {
    NSLog(@"foundservice: %@",aNetService);
}

- (void)rendezvousBrowser:(TCMRendezvousBrowser *)aBrowser didResolveService:(NSNetService *)aNetService {
//    [I_data addObject:[NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"resolved %@%@",[aNetService name],[aNetService domain]] forKey:@"serviceName"]];
    NSString *userID = [[aNetService TXTRecordDictionary] objectForKey:@"userid"];
    if (userID && ![userID isEqualTo:[TCMMMUserManager myID]]) {
        [I_foundUserIDs addObject:userID];
        [[TCMMMBEEPSessionManager sharedInstance] connectToNetService:aNetService];
    }
}

- (void)rendezvousBrowser:(TCMRendezvousBrowser *)aBrowser didRemoveResolved:(BOOL)wasResolved service:(NSNetService *)aNetService {
    NSLog(@"Removed Service: %@",aNetService);
}

#pragma mark -
#pragma mark ### TCMMMBrowserListViewDataSource methods ###

- (int)numberOfItemsInListView:(TCMMMBrowserListView *)aListView {
    return [I_data count];
}

- (int)listView:(TCMMMBrowserListView *)aListView numberOfChildrenOfItemAtIndex:(int)anItemIndex {
    if (anItemIndex>=0 && anItemIndex<[I_data count]) {
        NSMutableDictionary *item=[I_data objectAtIndex:anItemIndex];
        return [[item objectForKey:@"Sessions"] count];
    }
    return 0;
}

- (BOOL)listView:(TCMMMBrowserListView *)aListView isItemExpandedAtIndex:(int)anItemIndex {
    if (anItemIndex>=0 && anItemIndex<[I_data count]) {
        NSMutableDictionary *item=[I_data objectAtIndex:anItemIndex];
        return [[item objectForKey:@"isExpanded"] boolValue];
    }
    return YES;
}

- (void)listView:(TCMMMBrowserListView *)aListView setExpanded:(BOOL)isExpanded itemAtIndex:(int)anItemIndex {
    if (anItemIndex>=0 && anItemIndex<[I_data count]) {
        NSMutableDictionary *item=[I_data objectAtIndex:anItemIndex];
        [item setObject:[NSNumber numberWithBool:isExpanded] forKey:@"isExpanded"];
    }
}

- (id)listView:(TCMMMBrowserListView *)aListView objectValueForTag:(int)aTag ofItemAtIndex:(int)anItemIndex {
    if (anItemIndex>=0 && anItemIndex<[I_data count]) {
        NSMutableDictionary *item=[I_data objectAtIndex:anItemIndex];
        TCMMMUser *user=[[TCMMMUserManager sharedInstance] userForID:[item objectForKey:@"UserID"]];
    
        if (aTag==TCMMMBrowserItemNameTag) {
            return [user name];
        } else if (aTag==TCMMMBrowserItemStatusTag) {
            return [NSString stringWithFormat:@"%d Document(s)",[[item objectForKey:@"Sessions"] count]];
        } else if (aTag==TCMMMBrowserItemImageTag) {
            return [[user properties] objectForKey:@"Image32"];
        }
    }
    return nil;
}

- (id)listView:(TCMMMBrowserListView *)aListView objectValueForTag:(int)aTag atIndex:(int)anIndex ofItemAtIndex:(int)anItemIndex {
    if (anItemIndex>=0 && anItemIndex<[I_data count]) {
        NSDictionary *item=[I_data objectAtIndex:anItemIndex];
        TCMMMUser *user=[[TCMMMUserManager sharedInstance] userForID:[item objectForKey:@"UserID"]];
        NSArray *sessions=[item objectForKey:@"Sessions"];
        if (anIndex >= 0 && anIndex < [sessions count]) {
            TCMMMSession *session=[sessions objectAtIndex:anIndex];
            if (aTag==TCMMMBrowserChildNameTag) {
                return [session filename];
            } if (aTag==TCMMMBrowserChildIconImageTag) {
                return [[user properties] objectForKey:@"Image16"];
            }
        }
    }
    return nil;
}


#pragma mark -
#pragma mark ### TCMMMPresenceManager Notifications ###

- (int)TCM_indexOfItemWithUserID:(NSString *)aUserID {
    int result=-1;
    int i;
    for (i = 0; i < [I_data count]; i++) {
        if ([aUserID isEqualToString:[[I_data objectAtIndex:i] objectForKey:@"UserID"]]) {
            result=i;
            break;
        }
    }
    return result;
}

- (void)userDidChangeVisibility:(NSNotification *)aNotification {
    NSDictionary *userInfo=[aNotification userInfo];
    NSString *userID=[userInfo objectForKey:@"UserID"];
    BOOL isVisible=[[userInfo objectForKey:@"isVisible"] boolValue];
    // TODO: handle Selection
    if (isVisible) {
        [I_data addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:userID,@"UserID",[NSMutableArray array],@"Sessions",[NSNumber numberWithBool:YES],@"isExpanded",nil]];
    } else {
        int index=[self TCM_indexOfItemWithUserID:userID];
        if (index >= 0) {
            [I_data removeObjectAtIndex:index];
        }
    }
    [O_browserListView reloadData];
}

- (void)userDidChangeAnnouncedDocuments:(NSNotification *)aNotification {
    NSDictionary *userInfo=[aNotification userInfo];
    NSString *userID=[userInfo objectForKey:@"UserID"];
    int index=[self TCM_indexOfItemWithUserID:userID];
    if (index >= 0) {
        NSMutableDictionary *item=[I_data objectAtIndex:index];
        TCMMMSession *session=[userInfo objectForKey:@"AnnouncedSession"];
        NSMutableArray *sessions=[item objectForKey:@"Sessions"];
        if ([[userInfo objectForKey:@"Sessions"] count] == 0) {
            [sessions removeAllObjects];
        } else {
            if (session) {
                [sessions addObject:session];
            } else {
                NSString *concealedSessionID=[userInfo objectForKey:@"ConcealedSessionID"];
                int i;
                for (i = 0; i < [sessions count]; i++) {
                    if ([concealedSessionID isEqualToString:[[sessions objectAtIndex:i] sessionID]]) {
                        [sessions removeObjectAtIndex:i];
                        break;
                    }
                }
            }
        }
    }
    [O_browserListView reloadData];
}

@end
