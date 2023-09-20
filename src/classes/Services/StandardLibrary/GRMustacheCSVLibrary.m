// The MIT License
//
// Copyright (c) 2014 Gwendal Roué
// Copyright (c) 2019 Houdah Software s.à r.l.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheCSVLibrary_private.h"
#import "GRMustacheTag_private.h"
#import "GRMustacheContext_private.h"
#import "GRMustacheTranslateCharacters_private.h"


// =============================================================================
#pragma mark - GRMustacheCSVEscapeFilter

@implementation GRMustacheCSVEscapeFilter

#pragma mark <GRMustacheFilter>

/**
 * Support for {{ CSV.escape(value) }}
 */
- (id)transformedValue:(id)object
{
    // Specific case for [NSNull null]
    
    if (object == [NSNull null]) {
        return @"";
    }
    
    NSString *string = [object description];
    return [self escape:string];
}


#pragma mark - <GRMustacheRendering>

/**
 * Support for {{# CSV.escape }}...{{ value }}...{{ value }}...{{/ CSV.escape }}
 */
- (NSString *)renderForMustacheTag:(GRMustacheTag *)tag context:(GRMustacheContext *)context HTMLSafe:(BOOL *)HTMLSafe error:(NSError **)error
{
    switch (tag.type) {
        case GRMustacheTagTypeVariable:
            // {{ CSV.escape }}
            // Behave as a regular object: render self's description
            if (HTMLSafe != NULL) { *HTMLSafe = NO; }
            return [self description];
            
        case GRMustacheTagTypeSection:
            // {{# CSV.escape }}...{{/ CSV.escape }}
            // {{^ CSV.escape }}...{{/ CSV.escape }}
            
            // Render normally, but listen to all inner tags rendering, so that
            // we can format them. See mustacheTag:willRenderObject: below.
            context = [context contextByAddingTagDelegate:self];
            return [tag renderContentWithContext:context HTMLSafe:HTMLSafe error:error];
    }
}


#pragma mark - <GRMustacheTagDelegate>

/**
 * Support for {{# CSV.escape }}...{{ value }}...{{ value }}...{{/ CSV.escape }}
 */
- (id)mustacheTag:(GRMustacheTag *)tag willRenderObject:(id)object
{
    switch (tag.type) {
        case GRMustacheTagTypeVariable:
            // {{ value }}
            //
            // We can not escape `object`, because it is not a string.
            // We want to escape its rendering.
            // So return a rendering object that will eventually render `object`,
            // and escape its rendering.
            return [GRMustacheRendering renderingObjectWithBlock:^NSString *(GRMustacheTag *tag, GRMustacheContext *context, BOOL *HTMLSafe, NSError **error) {
                id<GRMustacheRendering> renderingObject = [GRMustacheRendering renderingObjectForObject:object];
                NSString *rendering = [renderingObject renderForMustacheTag:tag context:context HTMLSafe:HTMLSafe error:error];
                return [self escape:rendering];
            }];
            
        case GRMustacheTagTypeSection:
            // {{# value }}
            // {{^ value }}
            return object;
    }
}


#pragma mark - Private

- (NSString *)escape:(NSString *)string
{
    // Perform a first escaping using Apple's implementation.
    // It leaves many character unescaped. We'll have to go further.

	static NSCharacterSet *illegalCharacterSet = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		// https://tools.ietf.org/html/rfc4180
		illegalCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"\r\n\","] copy];
	});

	if ((string != nil) && ([string rangeOfCharacterFromSet:illegalCharacterSet].location != NSNotFound)) {
		NSMutableString *mutableString = [NSMutableString stringWithString:string];

		[mutableString replaceOccurrencesOfString:@"\"" withString:@"\"\"" options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
		[mutableString insertString:@"\"" atIndex:0];
		[mutableString appendString:@"\""];

		return [mutableString copy];
	}

    return string;
}

@end
