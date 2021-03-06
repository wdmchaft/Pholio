//
//  BDImagePickerController.m
//  ipad-portfolio
//
//  Created by Brian Dewey on 5/6/11.
//  Copyright 2011 Brian Dewey.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <CoreLocation/CoreLocation.h>
#import "IPAlert.h"
#import "BDImagePickerController.h"
#import "BDAssetsLibraryController.h"
#import "IPFlickrAuthorizationManager.h"
#import "IPFlickrSetPickerController.h"
#import "DropboxSDK.h"
#import "IPDropBoxAssetsSource.h"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@interface BDImagePickerController ()

//
//  Invoked when the user picks images.
//

@property (nonatomic, copy) BDImagePickerControllerImageBlock imageBlock;

//
//  Invoked when the user cancels.
//

@property (nonatomic, copy) BDImagePickerControllerCancelBlock cancelBlock;

//
//  The popover we're shown in.
//

@property (nonatomic, assign) UIPopoverController *popover;

//
//  Creates an assets library controller wrapped in a UINavigationController.
//

- (UINavigationController *)assetsLibraryController;

//
//  Creates a |IPFlickrSetPickerController| wrapped in a UINavigationController.
//

- (UINavigationController *)flickrController;

//
//  Creates an |BDAssetsGroupController| set up for DropBox, wrapped in a UINavigationController.
//

- (UINavigationController *)dropBoxController;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


@implementation BDImagePickerController

@synthesize delegate = delegate_;
@synthesize imageBlock = imageBlock_;
@synthesize cancelBlock = cancelBlock_;
@synthesize popover = popover_;

////////////////////////////////////////////////////////////////////////////////
//
//  Initializer.
//

- (id)init {
  
  self = [super init];
  return self;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Creates an assets library controller wrapped in a UINavigationController.
//

- (UINavigationController *)assetsLibraryController {
  
  BDAssetsLibraryController *libraryController = [[[BDAssetsLibraryController alloc] init] autorelease];
  UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:libraryController] autorelease];
  nav.navigationBar.barStyle = UIBarStyleBlack;
  libraryController.delegate = self;
  return nav;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Creates an |IPFlickrSetPickerController| wrapped in a |UINavigationController|.
//

- (UINavigationController *)flickrController {
  
  IPFlickrSetPickerController *controller = [[[IPFlickrSetPickerController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
  controller.delegate = self;
  UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:controller] autorelease];
  nav.navigationBar.barStyle = UIBarStyleBlack;
  return nav;
}

////////////////////////////////////////////////////////////////////////////////

- (UINavigationController *)dropBoxController {
  
  IPDropBoxAssetsSource *root = [[[IPDropBoxAssetsSource alloc] init] autorelease];
  root.path = @"/";
  BDAssetsGroupController *assetsController = [[[BDAssetsGroupController alloc] initWithStyle:UITableViewStylePlain] autorelease];
  assetsController.assetsSource = root;
  assetsController.title = kDropBox;
  assetsController.tabBarItem.image = [UIImage imageNamed:@"dropbox.png"];
  assetsController.delegate = self;
  UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:assetsController] autorelease];
  nav.navigationBar.barStyle = UIBarStyleBlack;
  return nav;
}

////////////////////////////////////////////////////////////////////////////////
//
//  Release any retained properties.
//

- (void)dealloc {

  [imageBlock_ release], imageBlock_ = nil;
  [cancelBlock_ release], cancelBlock_ = nil;
  [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Convenience constructor. This is how I expect things to get used.
//

+ (UIPopoverController *)presentPopoverFromRect:(CGRect)rect 
                                         inView:(UIView *)view 
                                    onSelection:(BDImagePickerControllerImageBlock)imageBlock {

  BDImagePickerController *controller = [[[BDImagePickerController alloc] init] autorelease];
  controller.imageBlock = imageBlock;
  UIViewController *picker;
  IPFlickrAuthorizationManager *authManager = [IPFlickrAuthorizationManager sharedManager];
  NSMutableArray *childControllers = [[[NSMutableArray alloc] init] autorelease];
  
  [childControllers addObject:[controller assetsLibraryController]];
  if (authManager.authToken != nil) {
    
    [childControllers addObject:[controller flickrController]];
  }
  if ([[DBSession sharedSession] isLinked]) {
    
    [childControllers addObject:[controller dropBoxController]];
  }
  
  if ([childControllers count] > 1) {
    
    UITabBarController *tab = [[[UITabBarController alloc] init] autorelease];
    [tab setViewControllers:childControllers];
    picker = tab;
    
  } else {
    
    picker = [childControllers objectAtIndex:0];
  }

  UIPopoverController *popover = [[[UIPopoverController alloc] initWithContentViewController:picker] autorelease];
  controller.popover = popover;
  [popover presentPopoverFromRect:rect inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
  return popover;
}

////////////////////////////////////////////////////////////////////////////////

+ (void)confirmLocationServicesAndPresentPopoverFromRect:(CGRect)rect
                                                  inView:(UIView *)view
                                             onSelection:(BDImagePickerControllerImageBlock)imageBlock
                                              setPopover:(BDImagePickerControllerSetPopoverBlock)setPopover {
  
  CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
  
  switch (authorizationStatus) {
    case kCLAuthorizationStatusRestricted:
    case kCLAuthorizationStatusDenied:
      [[IPAlert defaultAlert] showErrorMessage:kLocationServiceDenied];
      break;
      
    case kCLAuthorizationStatusNotDetermined:
    {
      setPopover = [setPopover copy];
      [[IPAlert defaultAlert] confirmWithDescription:kLocationServiceNotDetermined andButtonTitle:kOKString fromRect:rect inView:view performAction:^(void) {
        
        UIPopoverController *popover = [BDImagePickerController presentPopoverFromRect:rect inView:view onSelection:imageBlock];
        setPopover(popover);
        [setPopover release];
      }];
    }
      break;
      
    case kCLAuthorizationStatusAuthorized:
      setPopover([BDImagePickerController presentPopoverFromRect:rect inView:view onSelection:imageBlock]);
      break;
      
    default:
      break;
  }
}

#pragma mark - BDAssetsLibraryControllerDelegate

////////////////////////////////////////////////////////////////////////////////
//
//  Handle cancel.
//

- (void)bdImagePickerControllerDidCancel {
  
  if (self.cancelBlock != nil) {
    self.cancelBlock();
  }
  [self.delegate bdImagePickerControllerDidCancel];
  [self.popover dismissPopoverAnimated:YES];
}

////////////////////////////////////////////////////////////////////////////////
//
//  Handle images.
//

- (void)bdImagePickerDidPickImages:(NSArray *)images {
 
  if (self.imageBlock != nil) {

    self.imageBlock(images);
  }
  [self.delegate bdImagePickerDidPickImages:images];
  [self.popover dismissPopoverAnimated:YES];
}

@end
