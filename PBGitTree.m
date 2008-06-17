//
//  PBGitTree.m
//  GitTest
//
//  Created by Pieter de Bie on 15-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitTree.h"
#import "PBGitCommit.h"
#import "NSFileHandleExt.h"
#import "PBEasyPipe.h"

@implementation PBGitTree

@synthesize sha, path, repository, leaf, parent;

+ (PBGitTree*) rootForCommit:(id) commit
{
	PBGitCommit* c = commit;
	PBGitTree* tree = [[self alloc] init];
	tree.parent = nil;
	tree.leaf = NO;
	tree.sha = c.sha;
	tree.repository = c.repository;
	tree.path = @"";
	return tree;
}

+ (PBGitTree*) treeForTree: (PBGitTree*) prev andPath: (NSString*) path;
{
	PBGitTree* tree = [[self alloc] init];
	tree.parent = prev;
	tree.sha = prev.sha;
	tree.repository = prev.repository;
	tree.path = path;
	return tree;
}

- init
{
	children = nil;
	leaf = YES;
	return self;
}

- (NSString*) refSpec
{
	return [NSString stringWithFormat:@"%@:%@", self.sha, self.fullPath];
}

- (NSString*) contents
{
	if (!leaf)
		return [NSString stringWithFormat:@"This is a tree with path %@", self];

	NSFileHandle* handle = [repository handleForArguments:[NSArray arrayWithObjects:@"show", [self refSpec], nil]];
	NSData* data = [handle readDataToEndOfFile];
	NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return string;
}

- (NSString*) tmpFileNameForContents
{
	if (!leaf)
		return nil;
	NSLog(@"Getting tmp file");
	NSFileHandle* handle = [repository handleForArguments:[NSArray arrayWithObjects:@"show", [self refSpec], nil]];
	NSData* data = [handle readDataToEndOfFile];
	return [PBEasyPipe writeData:data toTempFileWithName:path];
}

- (NSArray*) children
{
	if (children != nil)
		return children;
	
	NSString* ref = [self refSpec];
	NSLog(@"Starting get for %@", ref);

	NSFileHandle* handle = [repository handleForArguments:[NSArray arrayWithObjects:@"show", ref, nil]];
	[handle readLine];
	[handle readLine];
	
	NSMutableArray* c = [NSMutableArray array];
	
	NSString* p = [handle readLine];
	while (p.length > 0) {
		BOOL isLeaf = ([p characterAtIndex:p.length - 1] != '/');
		if (!isLeaf)
			p = [p substringToIndex:p.length -1];

		PBGitTree* child = [PBGitTree treeForTree:self andPath:p];
		child.leaf = isLeaf;
		[c addObject: child];
		
		p = [handle readLine];
	}
	children = c;
	return c;
}

- (NSString*) fullPath
{
	if (!parent)
		return @"";
	
	if ([parent.fullPath isEqualToString:@""])
		return self.path;
	
	return [parent.fullPath stringByAppendingPathComponent: self.path];
}

@end