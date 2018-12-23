//
//  MidiKeyView.m
//  MidiKeys
//
//  Created by Chris Reed on Tue Oct 15 2002.
//  Copyright (c) 2002,2018 Chris Reed. All rights reserved.
//

#import "MidiKeyView.h"
#import "AppController.h"
#import "CTGradient.h"

// image file name
#define kOctaveDownImageFile @"OctaveDown.png"
#define kOctaveUpImageFile @"OctaveUp.png"

// key sizes
#define kNominalKeyHeight (57.0)
#define kWhiteKeyWidth (12.0)
#define kBlackKeyInset (4.0)
#define kBlackKeyWidth (8.0)
#define kBlackKeyHeight (32.0)

#define kWhiteKeysPerOctave (7)

//! Table to map note number within octave to details about that key.
const key_info_t kNoteInOctaveInfo[] = {
        [0] = { // C
            .isWhiteKey = YES,
            .rightIsInset = YES
        },
        [1] = { // C#
            .isBlackKey = YES,
            .numWhiteKeys = 1
        },
        [2] = { // D
            .isWhiteKey = YES,
            .numWhiteKeys = 1,
            .numBlackKeys = 1,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [3] = { // D#
            .isBlackKey = YES,
            .numWhiteKeys = 2,
            .numBlackKeys = 1,
        },
        [4] = {// E
            .isWhiteKey = YES,
            .numWhiteKeys = 2,
            .numBlackKeys = 2,
            .leftIsInset = YES,
        },
        [5] = { // F
            .isWhiteKey = YES,
            .numWhiteKeys = 3,
            .numBlackKeys = 2,
            .rightIsInset = YES,
        },
        [6] = { // F#
            .isBlackKey = YES,
            .numWhiteKeys = 4,
            .numBlackKeys = 2,
        },
        [7] = { // G
            .isWhiteKey = YES,
            .numWhiteKeys = 4,
            .numBlackKeys = 3,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [8] = { // G#
            .isBlackKey = YES,
            .numWhiteKeys = 5,
            .numBlackKeys = 3,
        },
        [9] = { // A
            .isWhiteKey = YES,
            .numWhiteKeys = 5,
            .numBlackKeys = 4,
            .rightIsInset = YES,
            .leftIsInset = YES,
        },
        [10] = { // A#
            .isBlackKey = YES,
            .numWhiteKeys = 6,
            .numBlackKeys = 4,
        },
        [11] = { // B
            .isWhiteKey = YES,
            .numWhiteKeys = 6,
            .numBlackKeys = 5,
            .leftIsInset = YES,
        },
};

@interface MidiKeyView (PrivateMethods)

- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note;
- (void)computeKeyValues;
- (NSBezierPath *)bezierPathForMidiNote:(int)note;
- (void)drawKey:(int)note;
- (void)drawKeyCapForNote:(int)note;
- (void)highlightMidiKey:(int)note;
- (int)midiNoteForMouse:(NSPoint)location;
- (void)drawOctaveOffsetIndicator;

@end

@implementation MidiKeyView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		mOctaveUpImage = [[NSImage imageNamed:kOctaveUpImageFile] retain];
		mOctaveDownImage = [[NSImage imageNamed:kOctaveDownImageFile] retain];
		mHighlightColour = [NSColor greenColor];
    }
    return self;
}

- (void)dealloc
{
	if (mClickedNote != -1)
	{
		// i don't know if this can happen, but no reason to take the chance
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
	}
	[mHighlightColour release];
	[mOctaveDownImage release];
	[mOctaveUpImage release];
	[super dealloc];
}

- (void)setDelegate:(id)delegate
{
	mDelegate = delegate;
}

- delegate
{
	return mDelegate;
}

- (void)computeKeyValues
{
	NSRect bounds = self.frame;
    double width = NSWidth(bounds);
    double height = NSHeight(bounds);
    _scale = height / kNominalKeyHeight;

    numOctaves = width / ((kWhiteKeyWidth * kWhiteKeysPerOctave * _scale) - 1.0);

//	NSLog(@"numOctaves = %d", numOctaves);

	// put middle c=60 in approx. center octave
	leftOctaves = numOctaves/2;
	firstMidiNote = 60 - (leftOctaves * 12);

//	NSLog(@"firstMidiNote = %d", firstMidiNote);

	// XXX really compute lastMidiNote
	lastMidiNote = KEY_COUNT; //firstMidiNote + int(bounds.size.width / kWhiteKeyWidth);
}

- (const key_info_t * _Nonnull)getKeyInfoForMidiNote:(int)note
{
	int theNote = note;
	int theOctave = (theNote - firstMidiNote) / 12;
	int octaveFirstNote = firstMidiNote + theOctave * 12;
	unsigned noteInOctave = theNote - octaveFirstNote;

    assert(noteInOctave < (sizeof(kNoteInOctaveInfo) / sizeof(key_info_t)));
    const key_info_t * octaveNoteInfo = &kNoteInOctaveInfo[noteInOctave];

    // Copy const key info, then set a few other fields.
    _keyInfo = *octaveNoteInfo;
	_keyInfo.theOctave = theOctave;
	_keyInfo.octaveFirstNote = octaveFirstNote;
	_keyInfo.noteInOctave = noteInOctave;

	return &_keyInfo;
}

- (NSBezierPath *)bezierPathForMidiNote:(int)note
{
    double scaledKeyHeight = kNominalKeyHeight * _scale;
    double scaledWhiteKeyWidth = kWhiteKeyWidth * _scale;
    double scaledBlackKeyWidth = kBlackKeyWidth * _scale;
    double scaledBlackKeyInset = kBlackKeyInset * _scale;
    double scaledBlackKeyHeight = kBlackKeyHeight * _scale;

	// get key info for the note
	const key_info_t * _Nonnull info = [self getKeyInfoForMidiNote:note];

	int theOctave = info->theOctave;
    double octaveLeft = (double)theOctave * ((scaledWhiteKeyWidth * kWhiteKeysPerOctave) - 1.0);
	int numWhiteKeys = info->numWhiteKeys;
	BOOL isBlackKey = info->isBlackKey;
	BOOL leftIsInset = info->leftIsInset;
	BOOL rightIsInset = info->rightIsInset; // black key insets on white keys

	NSRect keyRect;

	if (isBlackKey)
	{
		keyRect.origin.x = octaveLeft + numWhiteKeys * scaledWhiteKeyWidth - scaledBlackKeyInset;
		keyRect.origin.y = scaledKeyHeight - scaledBlackKeyHeight;
		keyRect.size.width = scaledBlackKeyWidth + 1.0;
		keyRect.size.height = scaledBlackKeyHeight - 1;

		return [NSBezierPath bezierPathWithRect:keyRect];
	}

	// white key
	double x, y, w, h;
	x = octaveLeft + numWhiteKeys * scaledWhiteKeyWidth - 1.0;
	y = 0.;
	w = scaledWhiteKeyWidth + 1.0;
	h = scaledKeyHeight - scaledBlackKeyHeight;

	NSBezierPath *keyPath = [NSBezierPath bezierPath];
	[keyPath moveToPoint:NSMakePoint(x+0.5, y+h-0.5)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y)];
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	if (rightIsInset)
	{
		[keyPath lineToPoint:NSMakePoint(x+w - scaledBlackKeyInset + 1, y+h)];
	}

	// start with white key part below the black keys
	y = scaledKeyHeight - scaledBlackKeyHeight - 1;
	h = scaledBlackKeyHeight;
	if (!rightIsInset && leftIsInset)
	{
		x += scaledBlackKeyInset - 1;
		w -= scaledBlackKeyInset - 1;
	}
	else if (rightIsInset && !leftIsInset)
	{
		w -= scaledBlackKeyInset - 1;
	}
	else if (rightIsInset && leftIsInset)
	{
		x += scaledBlackKeyInset - 1;
		w -= (scaledBlackKeyInset - 1) * 2;
	}
	[keyPath lineToPoint:NSMakePoint(x+w, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+h)];
	[keyPath lineToPoint:NSMakePoint(x+0.5, y+0.5)];
	[keyPath closePath];
	
	return keyPath;
}

- (void)drawKeyForNote:(int)note
{
    const key_info_t * _Nonnull keyInfo = [self getKeyInfoForMidiNote:note];

    NSColor * keyOutlineColor = [NSColor blackColor];
    NSColor * keyFillColor = keyInfo->isBlackKey ? [NSColor blackColor] : [NSColor whiteColor];

    [NSGraphicsContext saveGraphicsState];

    // Draw frame around the key
    NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
    [keyOutlineColor set];
    [keyPath stroke];
    [keyFillColor set];
    [keyPath fill];

    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawKeyCapForNote:(int)note
{
    NSPoint drawPoint;
    int offsetNote = note + mOctaveOffset * 12;
    if (offsetNote >= firstMidiNote && offsetNote < lastMidiNote)
    {
        const key_info_t * _Nonnull info = [self getKeyInfoForMidiNote:offsetNote];
        NSRect pathBounds = [[self bezierPathForMidiNote:offsetNote] bounds];
        NSMutableDictionary * attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:9.0 * _scale], NSFontAttributeName, nil];

        NSString * c = [mDelegate characterForMidiNote:note];
        NSSize capSize = [c sizeWithAttributes:attributes];
        double xOffset = ((pathBounds.size.width - capSize.width) / 2.0) - 0.5;

        if (info->isWhiteKey)
        {
            drawPoint.x = pathBounds.origin.x + xOffset;
            drawPoint.y = pathBounds.origin.y + 4.0;
        }
        else
        {
            drawPoint.x = pathBounds.origin.x + xOffset - 0.5;
            drawPoint.y = pathBounds.origin.y + 3.0;
            [attributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        }

        [c drawAtPoint:drawPoint withAttributes:attributes];
    }
}

- (void)highlightMidiKey:(int)note
{
	NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
	NSColor * darkerHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent]/2.0f brightness:[mHighlightColour brightnessComponent] alpha:[mHighlightColour alphaComponent]];
	NSColor * lighterHighlightColor = [NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent] brightness:[mHighlightColour brightnessComponent] alpha:[mHighlightColour alphaComponent]];

	// Draw the highlight
	[NSGraphicsContext saveGraphicsState];

	[keyPath setClip];

	CTGradient * gradient = [CTGradient gradientWithBeginningColor:darkerHighlightColor endingColor:lighterHighlightColor];
	[gradient fillRect:[keyPath bounds] angle:330.0f];

	[NSGraphicsContext restoreGraphicsState];

	// Draw frame around the highlighted key
	[NSGraphicsContext saveGraphicsState];

	[[NSColor colorWithCalibratedHue:[mHighlightColour hueComponent] saturation:[mHighlightColour saturationComponent] brightness:[mHighlightColour brightnessComponent]/3. alpha:[mHighlightColour alphaComponent]] set];
	[keyPath stroke];

	[NSGraphicsContext restoreGraphicsState];
}

// composite the up or down images into the view
- (void)drawOctaveOffsetIndicator
{
	if (mOctaveOffset == 0)
		return;

	NSRect bounds = [self bounds];
	NSPoint drawPoint;
	NSSize imageSize;
	NSImage *image;

	if (mOctaveOffset > 0)
	{
		// octave up
		image = mOctaveUpImage;
		imageSize = [image size];
		drawPoint = NSMakePoint(NSMaxX(bounds) - imageSize.width - 5.0, (NSHeight(bounds) - imageSize.height) / 2.0);
	}
	else
	{
		// octave down
		image = mOctaveDownImage;
		imageSize = [image size];
		drawPoint = NSMakePoint(5.0, (NSHeight(bounds) - imageSize.height) / 2.0);
	}

	float indicatorCompositeFraction = [[NSUserDefaults standardUserDefaults] floatForKey:@"OctaveOffsetIndicatorCompositeFraction"];
	if (indicatorCompositeFraction == 0.0)
	{
		[[NSUserDefaults standardUserDefaults] setFloat:0.25 forKey:@"OctaveOffsetIndicatorCompositeFraction"];
		indicatorCompositeFraction = 0.25;
	}

    [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:indicatorCompositeFraction];

	if (abs(mOctaveOffset) > 1)
	{
		int offsets = abs(mOctaveOffset) - 1;
		while (offsets--)
		{
			if (mOctaveOffset > 0)
				drawPoint.x -= imageSize.width * 0.5;
			else
				drawPoint.x += imageSize.width * 0.5;
            [image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:indicatorCompositeFraction];
		}
	}
}

// This is really quite inefficient, but it works out, and draws flicker-free
// thanks to the WindowServer's double buffering.
- (void)drawRect:(NSRect)rect
{
	if (!inited)
	{
		[self computeKeyValues];
		inited = YES;
	}

    // clear background
	NSDrawWhiteBezel(self.frame, rect);

	// determine whether to show key caps
	BOOL drawKeyCaps = _showKeycaps && mDelegate
            && [(NSObject *)mDelegate respondsToSelector:@selector(characterForMidiNote:)];

	// draw the keyboard one key at a time, starting with the leftmost visible note
	int i;
	for (i = firstMidiNote; i < lastMidiNote; ++i)
	{
        // Draw frame around the key
        [self drawKeyForNote:i];

		// highlight the key if it is on
		if (midiKeyStates[i])
		{
			[self highlightMidiKey:i];
		}

		// Draw the key cap for this key.
		if (drawKeyCaps)
		{
            [self drawKeyCapForNote:i];
		}
	}

	[self drawOctaveOffsetIndicator];
}

// recompute key values
- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
    // force recomputation of notes and sizes
    inited = NO;
    [self setNeedsDisplay:YES];
	[super resizeWithOldSuperviewSize:oldBoundsSize];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

//! Just tests if the point is within every key which is inefficient.
//!
//! @retval -1 on failure
- (int)midiNoteForMouse:(NSPoint)location
{
	int note;
	for (note = firstMidiNote; note < lastMidiNote; ++note)
	{
		NSBezierPath *keyPath = [self bezierPathForMidiNote:note];
		if ([keyPath containsPoint:location])
		{
			return note;
		}
	}

	return -1;
}

// find the note of the clicked key, send note on, and save the note
- (void)mouseDown:(NSEvent *)theEvent
{
	mClickedNote = [self midiNoteForMouse:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (mClickedNote != -1)
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:YES];
}

// get the key the mouse is currently over. if it's changed, send a note off
// for the old one, note on for the new one, save it and continue
- (void)mouseDragged:(NSEvent *)theEvent
{
	int currentNote = [self midiNoteForMouse:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
	if (currentNote != mClickedNote)
	{
		if (mClickedNote != -1)
			[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
		if (currentNote != -1)
			[mDelegate processMidiKeyClickWithNote:currentNote turningOn:YES];
		mClickedNote = currentNote;
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if (mClickedNote != -1)
	{
		[mDelegate processMidiKeyClickWithNote:mClickedNote turningOn:NO];
		mClickedNote = -1;
	}
}

// let the mDelegate object handle all the midi logic
- (void)keyDown:(NSEvent *)theEvent
{
//	NSLog(@"keyDown: %@; keycode = %d; timestamp = %g", [theEvent charactersIgnoringModifiers], [theEvent keyCode], (float)[theEvent timestamp]);
	// ignore keydowns generated by auto-key
	if ([theEvent isARepeat])
		return;
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:YES];
}

// send note offs
- (void)keyUp:(NSEvent *)theEvent
{
	[mDelegate processMidiKeyWithCode:[theEvent keyCode] turningOn:NO];
}

// we use counting for these methods instead of setting the states
// to boolean values because it is easily conceivable that multiple input
// sources would hit the same notes
- (void)turnMidiNoteOn:(int)note
{
    if (note < 0 || note > KEY_COUNT-1)
    {
        return;
    }
    if (midiKeyStates[note] < 254)
    {
        midiKeyStates[note]++;
    }
	[self setNeedsDisplay:YES];
}

- (void)turnMidiNoteOff:(int)note
{
	if (note < 0 || note > KEY_COUNT-1)
		return;
	if (midiKeyStates[note] > 0)
		midiKeyStates[note]--;
	[self setNeedsDisplay:YES];
}

- (void)turnAllNotesOff
{
    memset(&midiKeyStates, 0, sizeof(midiKeyStates));
    [self setNeedsDisplay:YES];
}

- (NSColor *)highlightColour
{
	return mHighlightColour;
}

- (void)setHighlightColour:(NSColor *)theColour
{
	if (theColour)
	{
		[mHighlightColour release];
		mHighlightColour = [theColour retain];
	}
}

- (int)octaveOffset
{
	return mOctaveOffset;
}

- (void)setOctaveOffset:(int)offset
{
	mOctaveOffset = offset;
	[self setNeedsDisplay:YES];
}

- (BOOL)showKeycaps
{
	return _showKeycaps;
}

- (void)setShowKeycaps:(BOOL)show
{
	if (show != _showKeycaps)
	{
		_showKeycaps = show;
		[self setNeedsDisplay:YES];
	}
}

@end
