//
// Copyright 2010 Itty Bitty Apps Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License. You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

#import "IBAFormFieldCell.h"
#import "IBAFormConstants.h"
#import "IBAInputManager.h"

@interface IBAFormFieldCell ()
@property (nonatomic, assign, getter=isActive) BOOL active;
@end


@implementation IBAFormFieldCell

@synthesize inputView = inputView_;
@synthesize inputAccessoryView = inputAccessoryView_;
@synthesize cellView = cellView_;
@synthesize label = label_;
@synthesize formFieldStyle = formFieldStyle_;
@synthesize styleApplied = styleApplied_;
@synthesize active = active_;

- (void)dealloc {
	IBA_RELEASE_SAFELY(inputView_);
	IBA_RELEASE_SAFELY(inputAccessoryView_);
	IBA_RELEASE_SAFELY(cellView_);
	IBA_RELEASE_SAFELY(label_);
	IBA_RELEASE_SAFELY(formFieldStyle_);
	
	[super dealloc];
}

- (id)initWithFormFieldStyle:(IBAFormFieldStyle *)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;

		self.cellView = [[[UIView alloc] initWithFrame:self.contentView.bounds] autorelease];
		self.cellView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.cellView.userInteractionEnabled = YES;
		[self.contentView addSubview:self.cellView];

		// Create a label
		self.label = [[[UILabel alloc] initWithFrame:style.labelFrame] autorelease];
		self.label.autoresizingMask = style.labelAutoresizingMask;
		self.label.adjustsFontSizeToFitWidth = YES;
		self.label.minimumFontSize = 10;
		[self.cellView addSubview:self.label];

		// set the style after the views have been created
		self.formFieldStyle = style;
	}

    return self;
}

- (void)activate {
  [self beginObservingSuperviewContentOffset];
	[self applyActiveStyle];
	self.active = YES;
}


- (void)deactivate {
  [self endObservingSuperviewContentOffset];
	[self applyFormFieldStyle];
	self.active = NO;
}

- (void)setFormFieldStyle:(IBAFormFieldStyle *)style {
	if (style != formFieldStyle_) {
		IBAFormFieldStyle *oldStyle = formFieldStyle_;
		formFieldStyle_ = [style retain];
		IBA_RELEASE_SAFELY(oldStyle);
		
		self.styleApplied = NO;
	}
}

- (void)applyFormFieldStyle {
	self.label.font = self.formFieldStyle.labelFont;
	self.label.textColor = self.formFieldStyle.labelTextColor;
	self.label.textAlignment = self.formFieldStyle.labelTextAlignment;
	self.label.backgroundColor = self.formFieldStyle.labelBackgroundColor;
	self.backgroundColor = self.formFieldStyle.labelBackgroundColor;

	self.styleApplied = YES;
}

- (void)applyActiveStyle {
	self.label.backgroundColor = self.formFieldStyle.activeColor;
	self.backgroundColor = self.formFieldStyle.activeColor;
}

- (void)updateActiveStyle {
    if ([self isActive]) {
		// We need to reapply the active style because the tableview has a nasty habbit of resetting the cell background 
		// when the cell is reattached to the view hierarchy.
		[self applyActiveStyle]; 
	}
}

- (void)drawRect:(CGRect)rect {
	if (!self.styleApplied) {
		[self applyFormFieldStyle];
	}

	[super drawRect:rect];
}

- (CGSize)sizeThatFits:(CGSize)size
{
  return [self.cellView bounds].size;
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

#pragma mark - Dirty laundry

// SP: A new OS, some new dirty laundry. Why are we doing this craziness you may ask?
// Here's an excerpt from SW's comment from the previous iOS 4/iOS 5 fix:
// "..let me tell you a little story about UIResponders. If you call becomeFirstResponder
// on a UIResponder that is not in the view hierarchy, it doesn't become the first responder.
// 'So what', you might ask. Well, when cells in a UITableView scroll out of view, they are
// removed from the view hierarchy. If you select a cell, then scroll it up out of view,
// when you press the 'Previous' button in the toolbar, the forms framework tries to activate
// the previous cell and make it the first responder. The previous cell won't be in the view
// hierarchy, and the becomeFirstResponder call will fail.."
// The previous fix relied on didMoveToWindow to keep track of cells moving offscreen, however
// in iOS 6, this call no longer gets triggered. As a result we're having to keep track of our
// position within our superview and our superviews contentOffset. Instead of keeping unused
// cells around in the responder chain so we can resign them as first responder, we're now
// resigning the cells as soon as they pass off the top of the screen.


static NSString *kContentOffsetKeyPath = @"contentOffset";

- (void)beginObservingSuperviewContentOffset
{
  if ([self.superview respondsToSelector:@selector(contentOffset)])
  {
    [self.superview addObserver:self forKeyPath:kContentOffsetKeyPath options:NSKeyValueObservingOptionNew context:NULL];
  }
}

- (void)endObservingSuperviewContentOffset
{
  if ([self.superview respondsToSelector:@selector(contentOffset)])
  {
    [self.superview removeObserver:self forKeyPath:kContentOffsetKeyPath];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:kContentOffsetKeyPath])
  {
    CGPoint contentOffset = [[change valueForKey:NSKeyValueChangeNewKey] CGPointValue];
    if (CGRectGetMaxY(self.frame) <= contentOffset.y)
    {
      [[IBAInputManager sharedIBAInputManager] deactivateActiveInputRequestor];
    }
  }
}

@end
