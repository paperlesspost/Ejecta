#import <objc/runtime.h>

#import "EJAppViewController.h"
#import "EJJavaScriptView.h"

@implementation EJAppViewController

- (instancetype)initWithScriptAtPath:(NSString *)pathp {
	
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {

        [self setPath:pathp];
        
    }
    return self;
}

- (void)dealloc {
	[_path release];
    _path = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
	[(EJJavaScriptView *)self.view clearCaches];
	[super didReceiveMemoryWarning];
}

- (void)loadView {
    
	CGRect frame = UIScreen.mainScreen.bounds;

	EJJavaScriptView *view = [[EJJavaScriptView alloc] initWithFrame:frame];
    [self setView:view];
	[view loadScriptAtPath:_path];
	[view release];
}

@end
