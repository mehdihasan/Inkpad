//
//  WDTextController.m
//  Inkpad
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2010-2013 Steve Sprang
//

#import <CoreText/CoreText.h>
#import "WDCanvasController.h"
#import "WDDrawingController.h"
#import "WDCoreTextLabel.h"
#import "WDFontController.h"
#import "WDFontManager.h"
#import "WDInspectableProperties.h"
#import "WDPropertyManager.h"

#define kMinFontSize            1
#define kMaxFontSize            200
#define kTableFadeRadius        6
#define kCoreTextLabelTag       1

@implementation WDFontController

@synthesize drawingController = drawingController_;
@synthesize selectedFontName = selectedFontName_;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) setDrawingController:(WDDrawingController *)drawingController
{
    drawingController_ = drawingController;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(invalidProperties:)
                                                 name:WDInvalidPropertiesNotification
                                               object:drawingController.propertyManager];
}

- (IBAction) decrement:(id)sender
{
    sizeSlider_.value = sizeSlider_.value - 1;
    [sizeSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction) increment:(id)sender
{
    sizeSlider_.value = sizeSlider_.value + 1;
    [sizeSlider_ sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (IBAction) takeFontSizeFrom:(id)sender
{
    int size = round([(UISlider *)sender value]);
    
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
}

- (IBAction) takeFinalFontSizeFrom:(id)sender
{
    int size = round([(UISlider *)sender value]);
    
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
    
    [drawingController_ setValue:@(size) forProperty:WDFontSizeProperty];
}

- (IBAction) takeAlignmentFrom:(id)sender
{
    [drawingController_ setValue:@(alignment_.selectedSegmentIndex) forProperty:WDTextAlignmentProperty];
}

- (IBAction) returnToFamilyList:(id)sender
{
    [self setViewByFamily:YES];
}

- (void)setViewByFamily:(BOOL)enabled
{
    viewByFamily_ = enabled;
    
    if (viewByFamily_) {
        self.title = NSLocalizedString(@"Font Families", @"Font Families");
        self.navigationItem.leftBarButtonItem = nil;
        [table_ setFrame:CGRectMake(0, 0, 320, 442)];
    } else {
        self.title = NSLocalizedString(@"Fonts", @"Fonts");
        self.navigationItem.leftBarButtonItem = familiesButton_;
        [table_ setFrame:CGRectMake(0, 0, 320, 330)];
    }
    
    [controls_ setHidden:viewByFamily_];
    [table_ reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setViewByFamily:YES];
    
    sizeSlider_.minimumValue = kMinFontSize;
    sizeSlider_.maximumValue = kMaxFontSize;
    
    alignment_.selectedSegmentIndex = [[drawingController_.propertyManager defaultValueForProperty:WDTextAlignmentProperty] intValue];
    [alignment_ addTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
    
    int size = [[drawingController_.propertyManager defaultValueForProperty:WDFontSizeProperty] intValue];
    sizeSlider_.value = size;
    sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
    
    

    self.preferredContentSize = self.view.frame.size;
}

- (void) scrollToSelectedFont
{
//    if (viewByFamily_ == NO) {
//        NSString *defaultFontName = [drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty];
//        NSUInteger fontIndex = [[[WDFontManager sharedInstance] supportedFonts] indexOfObject:defaultFontName];
//        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:fontIndex inSection:0];
//        [table_ scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
//    }
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [table_ reloadData];
//    [self scrollToSelectedFont];
}

- (void) invalidProperties:(NSNotification *)aNotification
{
    NSSet *properties = [aNotification userInfo][WDInvalidPropertiesKey];
    
    for (NSString *property in properties) {
        id value = [drawingController_.propertyManager defaultValueForProperty:property];
        
        if ([property isEqualToString:WDFontNameProperty]) {
            if (![value isEqualToString:self.selectedFontName]) {
                [table_ reloadData];
                [self scrollToSelectedFont];
            }
        } else if ([property isEqualToString:WDFontSizeProperty]) {
            int size = [value intValue];
            
            sizeSlider_.value = size;
            sizeLabel_.text = [NSString stringWithFormat:@"%d pt", size];
        } else if ([property isEqualToString:WDTextAlignmentProperty]) {
            [alignment_ removeTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
            alignment_.selectedSegmentIndex = [value intValue];
            [alignment_ addTarget:self action:@selector(takeAlignmentFrom:) forControlEvents:UIControlEventValueChanged];
        }
    }
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (viewByFamily_)
    {
        return [[[WDFontManager sharedInstance] supportedFamilies] count];
    }
    
    return [[[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString        *cellIdentifier = @"fontIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        WDCoreTextLabel *label = [[WDCoreTextLabel alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 10, 0)];
        label.tag = kCoreTextLabelTag;
        [cell.contentView addSubview:label];
    }
    
    WDCoreTextLabel *previewLabel = (WDCoreTextLabel *) [cell viewWithTag:kCoreTextLabelTag];
    
    if (viewByFamily_) {
        NSString *familyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        cell.textLabel.text = familyName;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        [previewLabel setText:nil];
    } else {
        NSString *fontName = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        
        if ([fontName isEqualToString:[drawingController_.propertyManager defaultValueForProperty:WDFontNameProperty]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            self.selectedFontName = fontName;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        // Clear family name
        cell.textLabel.text = nil;
        
        CTFontRef fontRef = [[WDFontManager sharedInstance] newFontRefForFont:fontName withSize:20];
        [previewLabel setFontRef:fontRef];
        CFRelease(fontRef);
        
        [previewLabel setText:[[WDFontManager sharedInstance] displayNameForFont:fontName]];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (viewByFamily_) {
        self.selectedFamilyName = [[WDFontManager sharedInstance] supportedFamilies][indexPath.row];
        [self setViewByFamily:NO];
    } else {
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
        UITableViewCell *oldCell = nil;
        NSIndexPath     *oldIndexPath = nil; 
        
        // find old cell
        NSUInteger oldRow = [[[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName] indexOfObject:self.selectedFontName];
        oldIndexPath = [NSIndexPath indexPathForRow:oldRow inSection:indexPath.section];
        oldCell = [tableView cellForRowAtIndexPath:oldIndexPath];
        self.selectedFontName = nil;
        
        // deselect old cell
        if (oldCell.accessoryType == UITableViewCellAccessoryCheckmark) {
            oldCell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        // select new value
        if (newCell.accessoryType == UITableViewCellAccessoryNone) {
            newCell.accessoryType = UITableViewCellAccessoryCheckmark;
            self.selectedFontName = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        }
        
        NSString *font = [[WDFontManager sharedInstance] fontsInFamily:self.selectedFamilyName][indexPath.row];
        [drawingController_ setValue:font forProperty:WDFontNameProperty];
    }
}

@end
