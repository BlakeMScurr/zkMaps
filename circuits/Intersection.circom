pragma circom 2.0.0;

/*
Returns 1 if two line segments intersect, 0 otherwise
Each segment is defined by their endpoints
*/
template SegmentsIntersect() {
    signal input segment1[4];
    signal input segment2[4];
    signal output out;

    // Find the slope-intercept form of the line for each segment
    component line1C = SlopeInterceptOfSegment();
    line1C.segment <== segment1;
    signal line1 <== line1C.rationalLine;

    component line2C = SlopeInterceptOfSegment();
    line2C.segment <== segment1;
    signal line2 <== line2C.rationalLine;

    // Make sure the lines intersect
    component linesIntersectC = LinesIntersect();
    linesIntersectC.rationalLine1 <== line1;
    linesIntersectC.rationalLine2 <== line2;
    signal linesIntersect <== linesIntersectC.out;

    // Find the intersection of the lines
    component intersectionC = Intersection();
    intersectionC.rationalLine1 <== line1;
    intersectionC.rationalLine2 <== line2;
    signal intersection <== intersectionC.8rationalIntersection;

    // Check if the intersection is on both segments
    component intersectionInSegment1C = PointInSegment();
    intersectionInSegment1C.segment <== segment1;
    intersectionInSegment1C.8rationalPoint <== intersection;
    intersectionInSegment1 <== intersectionInSegment1C.out;

    component intersectionInSegment2C = PointInSegment();
    intersectionInSegment2C.segment <== segment2;
    intersectionInSegment2C.8rationalPoint <== intersection;
    intersectionInSegment2 <== intersectionInSegment2C.out;

    // Output whether the lines intersect and the intersection is within both segments
    signal intersectionInSegment <== intersectionInSegment1 * intersectionInSegment2;
    out <== linesIntersect * intersectionInSegment;
}

/*
Returns 1 if two lines intersect, 0 otherwise
Lines are in slope-intercept form with rational numbers
*/
template LinesIntersect() {
    signal input rationalLine1[4];
    signal input rationalLine2[4];
    signal output out;

    // Return 0 if their slopes are the same but their intercepts are different
    // REQUIRES: 2-rational equality, 2-rational inequality
}

/*
Returns the intersection of two lines
Assumes they intersect
Lines are in slope intercept form
*/
template Intersection() {
    signal input rationalLine1[4];
    signal input rationalLine2[4];
    signal output 8rationalIntersection[16];

    //    m1x + c1 = m2x + c2
    // => m1x - m2x = c2 - c1
    // => x(m1 - m2) = c2 - c1
    // => x = (c2 - c1)/(m1x - m2x)
    //
    //    y = m1x + c1
    //      = m1(c2 - c1)/(m1x - m2x)
    // 
    // REQUIRES: 2-rational subtraction, 2-rational addition, 2-rational division, 4-rational multiplication (if 2-rational isn't closed under multiplication) 
}

/*
Returns the equation of a line in slope intercept form given a line
segment defined by its endpoints
*/
template SlopeInterceptOfSegment() {
    signal input segment[4];
    signal output rationalLine[4];

    // m = (y2 - y1)/(x2 - x1)
    //
    //    y1 = mx1 + c
    // =>  c = y1 - mx1
    // =>  c = y1 - (y2 - y1)/(x2 - x1)
    //
    // REQUIRES: integer to rational division, 2-rational subtraction, integer to rational
}

/*
Returns 1 if a point lies along a line segment, 0 otherwise
Assume that the point is actually on the line
*/
template PointInSegment() {
    signal input segment[4];
    signal input 8rationalPoint[16];
    signal output out;

    // REQUIRES: integer to 8rational, 8rational comparison
}