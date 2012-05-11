//
//  ComObscureTiCarouselCarouselViewProxy.m
//  ticarousel
//
//  Created by Paul Mietz Egli on 5/10/12.
//  Copyright (c) 2012 Paul Mietz Egli. All rights reserved.
//

#import "ComObscureTiCarouselCarouselViewProxy.h"
#import "ComObscureTiCarouselCarouselView.h"

#define kCarouselEventObjectName @"carousel"
#define kCarouselScrollEvent @"scroll"
#define kCarouselChangeEvent @"change"

NSArray * carouselKeySequence;


@implementation ComObscureTiCarouselCarouselViewProxy

- (void)dealloc {
    RELEASE_TO_NIL(carouselKeySequence)

    // clean up views
	pthread_rwlock_destroy(&viewsLock);
	[viewProxies makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
	[viewProxies release];
    [super dealloc];
}

#pragma mark View Management

- (void)lockViews {
	pthread_rwlock_rdlock(&viewsLock);
}

- (void)lockViewsForWriting {
	pthread_rwlock_wrlock(&viewsLock);
}

- (void)unlockViews {
	pthread_rwlock_unlock(&viewsLock);
}

#pragma mark Public API

- (void)setViews:(id)args {
	ENSURE_ARRAY(args);
	for (id newViewProxy in args) {
		[self rememberProxy:newViewProxy];
		[newViewProxy setParent:self];
	}
	[self lockViewsForWriting];
	for (id oldViewProxy in viewProxies) {
		if (![args containsObject:oldViewProxy]) {
			[oldViewProxy setParent:nil];
			TiThreadPerformOnMainThread(^{[oldViewProxy detachView];}, NO);
			[self forgetProxy:oldViewProxy];
		}
	}
	[viewProxies autorelease];
	viewProxies = [args mutableCopy];
	[self unlockViews];
	[self replaceValue:args forKey:@"views" notification:YES];
}

/*
 * padding between views
 */
- (void)setHorizontalPadding:(id)arg {
    horizontalPadding = [TiUtils intValue:arg];
}

#pragma mark -
#pragma mark iCarouselDataSource

- (NSUInteger)numberOfItemsInCarousel:(iCarousel *)carousel {
    return [viewProxies count];
}

- (UIView *)carousel:(iCarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusingView:(UIView *)_view {
    // since we build the views in js-land, we don't reuse anything here
    TiViewProxy * proxy = [viewProxies objectAtIndex:index];
    return proxy.view;
}

#pragma mark -
#pragma mark iCarouselDelegate

- (CGFloat)carouselItemWidth:(iCarousel *)carousel {
    NSInteger max = 0;
    for (TiViewProxy * proxy in viewProxies) {
        max = MAX(max, proxy.view.bounds.size.width);
    }
    return max + horizontalPadding;
}

- (void)carouselDidEndScrollingAnimation:(iCarousel *)carousel {
    NSDictionary * obj = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInteger:carousel.currentItemIndex], @"currentPage",
                          nil];
    [self fireEvent:kCarouselScrollEvent withObject:obj];
}

- (void)carouselCurrentItemIndexUpdated:(iCarousel *)carousel {
    NSDictionary * obj = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInteger:carousel.currentItemIndex], @"currentPage",
                          nil];
    [self fireEvent:kCarouselChangeEvent withObject:obj];
}

@end
