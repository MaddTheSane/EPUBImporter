//
//  GNJUnZip.h
//  EPUBImporter
//
//  Created by Genji on 11/07/12.
//  Copyright 2011 Genji App. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "minizip/unzip.h"

/**
 * GNJUnZip object is a wrapper object for minizip's unzip.
 */
@interface GNJUnZip : NSObject
{
  unzFile unzipFile_;
}

/** The path of zip file */
@property (nonatomic, readonly) NSString *path;

/** The items contained in the zip archive. */
@property (unsafe_unretained, nonatomic, readonly) NSArray *items;

- (id)initWithZipFile:(NSString *)path;
- (NSData *)dataWithContentsOfFile:(NSString *)path;

@end
