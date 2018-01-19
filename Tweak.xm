
#import <UIKit/UIKit.h>
#import <dlfcn.h>

#import <mach/port.h>
#import <mach/kern_return.h>

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <netdb.h>

#import <mach/port.h>
#import <mach/kern_return.h>
#import "fishhook.h"


#define KEY_SECONDS @"KEY_SECONDS"


int gStartTimestamp = 0;
int gPreRealTimestamp = 0;

#define ADD_INTERVAL 3600 * 2 // 2h

int	(*orig_gettimeofday)(struct timeval * val, void * tmp);
int	my_gettimeofday(struct timeval * val, void * tmp) {
	//return 0 for success, or -1 for failure
	int retval = orig_gettimeofday(val, tmp);

	//NSLog(@"my_gettimeofday,  retval %d, time %d, %d",  (int) retval, (int)val->tv_sec, (int) val->tv_usec );
	int addSeconds = 0;
	if (gPreRealTimestamp > 0) {
		addSeconds = gPreRealTimestamp - val->tv_sec;
	}
	gPreRealTimestamp = val->tv_sec;

	if (0 == gStartTimestamp) {
		if (val->tv_sec > gStartTimestamp) {
			gStartTimestamp = val->tv_sec;
		} 		
	}
	val->tv_sec = gStartTimestamp + addSeconds;

	return retval;
}

%ctor {

    NSLog(@"entry");
    /*
struct timeval start;
gettimeofday(&start,NULL);
printf("start.tv_sec:%dn",start.tv_sec);
printf("start.tv_usec:%dn",start.tv_usec);
*/

    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
	gStartTimestamp = [userDefaultes integerForKey: KEY_SECONDS];

    rebind_symbols((struct rebinding[1]){{"gettimeofday", (void *)my_gettimeofday, (void**) (void *)&orig_gettimeofday}}, 1);
    NSLog(@"orig_gettimeofday %p", orig_gettimeofday);

}


%hook UnityAppController

- (void)applicationDidEnterBackground:(id)arg1 {
    %orig;

    gStartTimestamp = gStartTimestamp + ADD_INTERVAL;
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    [userDefaultes setInteger: gStartTimestamp forKey: KEY_SECONDS];
    [userDefaultes synchronize];
    NSLog(@"applicationDidEnterBackground, set time to %d", gStartTimestamp );
    
}

%end
