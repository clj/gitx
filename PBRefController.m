//
//  PBLabelController.m
//  GitX
//
//  Created by Pieter de Bie on 21-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBRefController.h"
#import "PBGitRevisionCell.h"
#import "PBRefMenuItem.h"

@implementation PBRefController

- (void)awakeFromNib
{
	[commitList registerForDraggedTypes:[NSArray arrayWithObject:@"PBGitRef"]];
}

- (void) removeRef:(PBRefMenuItem *) sender
{
	int ret = 1;
	[historyController.repository outputForArguments:[NSArray arrayWithObjects:@"update-ref", @"-d", [[sender ref] ref], nil] retValue: &ret];
	if (ret) {
		NSLog(@"Removing ref failed!");
		return;
	}

	[[sender commit] removeRef:[sender ref]];
	[commitController rearrangeObjects];
}

- (void) checkoutRef:(PBRefMenuItem *)sender
{
	int ret = 1;
	[historyController.repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"checkout", [[sender ref] shortName], nil] retValue: &ret];
	if (ret) {
		[[NSAlert alertWithMessageText:@"Checking out branch failed"
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:@"There was an error checking out the branch. Perhaps your working directory is not clean?"] runModal];
		return;
	}
	[historyController.repository reloadRefs];
}

- (NSArray *) menuItemsForRef:(PBGitRef *)ref commit:(PBGitCommit *)commit
{
	return [PBRefMenuItem defaultMenuItemsForRef:ref commit:commit target:self];
}

# pragma mark Tableview delegate methods

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	NSPoint location = [tv convertPointFromBase:[(PBCommitList *)tv mouseDownPoint]];
	int row = [tv rowAtPoint:location];
	int column = [tv columnAtPoint:location];
	if (column != 0)
		return NO;
	
	PBGitRevisionCell *cell = (PBGitRevisionCell *)[tv preparedCellAtColumn:column row:row];
	
	int index = [cell indexAtX:location.x];
	
	if (index == -1)
		return NO;
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:row], [NSNumber numberWithInt:index], NULL]];
	[pboard declareTypes:[NSArray arrayWithObject:@"PBGitRef"] owner:self];
	[pboard setData:data forType:@"PBGitRef"];
	
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if (operation == NSTableViewDropAbove)
		return NSDragOperationNone;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	if ([pboard dataForType:@"PBGitRef"])
		return NSDragOperationMove;
	
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)operation
{
	if (operation != NSTableViewDropOn)
		return NO;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	NSData *data = [pboard dataForType:@"PBGitRef"];
	if (!data)
		return NO;
	
	NSArray *numbers = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	int oldRow = [[numbers objectAtIndex:0] intValue];
	int oldRefIndex = [[numbers objectAtIndex:1] intValue];
	PBGitCommit *oldCommit = [[commitController arrangedObjects] objectAtIndex: oldRow];
	PBGitRef *ref = [[oldCommit refs] objectAtIndex:oldRefIndex];
	
	PBGitCommit *dropCommit = [[commitController arrangedObjects] objectAtIndex:row];
	
	int a = [[NSAlert alertWithMessageText:@"Change branch"
							 defaultButton:@"Change"
						   alternateButton:@"Cancel"
							   otherButton:nil
				 informativeTextWithFormat:@"Do you want to change branch\n\n\t'%@'\n\n to point to commit\n\n\t'%@'", [ref shortName], [dropCommit subject]] runModal];
	if (a != NSAlertDefaultReturn)
		return NO;
	
	int retValue = 1;
	[historyController.repository outputForArguments:[NSArray arrayWithObjects:@"update-ref", @"-mUpdate from GitX", [ref ref], [dropCommit sha], NULL] retValue:&retValue];
	if (retValue)
		return NO;
	
	[dropCommit addRef:ref];
	[oldCommit removeRef:ref];
	
	[commitController rearrangeObjects];
	[aTableView needsToDrawRect:[aTableView rectOfRow:oldRow]];
	return YES;
}

# pragma mark Add ref methods
-(void)addRef:(id)sender
{
	[NSApp beginSheet:newBranchSheet
	   modalForWindow:[[historyController view] window]
		modalDelegate:NULL
	   didEndSelector:NULL
		  contextInfo:NULL];
}

-(void)saveSheet:(id) sender
{
	NSString *branchName = [@"refs/heads/" stringByAppendingString:[newBranchName stringValue]];
	[self closeSheet:sender];
	
	if ([[commitController selectedObjects] count] == 0)
		return;
	
	PBGitCommit *commit = [[commitController selectedObjects] objectAtIndex:0];
	int retValue = 1;
	[historyController.repository outputForArguments:[NSArray arrayWithObjects:@"update-ref", @"-mCreate branch from GitX", branchName, [commit sha], NULL] retValue:&retValue];
	if (retValue)
	{
		NSLog(@"Creating ref failed!");
		return;
	}

	[commit addRef:[PBGitRef refFromString:branchName]];
	[commitController rearrangeObjects];
}

-(void)closeSheet:(id) sender
{	
	[NSApp endSheet:newBranchSheet];
	[newBranchName setStringValue:@""];
	[newBranchSheet orderOut:self];
}

@end
