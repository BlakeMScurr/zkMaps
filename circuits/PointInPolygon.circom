pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/sign.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/compconstant.circom";

/*
Returns 1 if a given point is in an n sided polygon, 0 otherwise.
Implements ray tracing algorithm for simple polygons on a discrete 2^grid_bits length plane.
Note, we don't check for complex or degenerate polygon.
*/
template RayTracing(n, grid_bits, p) {
    signal input point[2];
    signal input polygon[n][2];
    signal output out;

    // Check that (2^grid_bits)^2 < p to prevent overflow
    assert((2**grid_bits)**2 < p);

    // Make sure every vertex in the polygon is in the range [0, 2^grid_bits)
    // Disallow vertices on the y-axis
    component x_comp[n];
    component y_comp[n];
    for (var i=0; i<n; i++) {
        x_comp[i] = CompConstant(grid_bits**2);
        x_comp[i].in <== polygon[i][0];
        x_comp[i].out === 0;

        y_comp[i] = CompConstant(grid_bits**2 - 1);
        y_comp[i].in <== polygon[i][1];
        y_comp[i].out === 0;
    }

    // Make sure the point is in the range (0, 2^grid_bits)
    component comp;
    for (var i=0; i<2; i++) {
        comp[i] = CompConstant(grid_bits**2);
        comp[i].in <== point[i];
        comp[i].out === 0;
    }

    // Make sure no vertices share a y coordinate with the point
    // This avoids edge cases where the ray intersects the polygon at a corner
    // Note that it means we don't consider these points to be inside the polygon
    

    // Count the number of intersections with the ray
    // For each edge, determine whether the ray intersects the edge
    // Return whether the number of intersections is even, meaning the point is outside the polygon
}

/*
Returns 1 if two lines segments intersect, 0 otherwise.
*/
template Intersects(grid_bits) {
    signal input line1[2][2];
    signal input line2[2][2];
    signal output out;

    /*
    Setup orientation circuits:
        Orientation[0] takes inputs line1 and line2[0]
        Orientation[1] takes inputs line1 and line2[1]
        Orientation[2] takes inputs line2 and line2[0]
        Orientation[3] takes inputs line2 and line2[1]

    Similarly for onSegment circuits
    */
    component orientation[4];
    component onSegment[4];
    for (var i=0; i<2; i++) {
        // Orientation with respect to line1

        orientation[i] = Orientation(grid_bits);
        // line1 point 1
        orientation[i].points[0][0] <== line1[0][0];
        orientation[i].points[0][1] <== line1[0][1];
        // line1 point 2
        orientation[i].points[1][0] <== line1[1][0];
        orientation[i].points[1][1] <== line1[1][1];
        // line2 point i
        orientation[i].points[2][0] <== line2[i][0];
        orientation[i].points[2][1] <== line2[i][1];

        // Point on line 1
        onSegment[i] = OnSegment(grid_bits);
        onSegment[i].line[0][0] <== line1[0][0];
        onSegment[i].line[0][1] <== line1[0][1];
        onSegment[i].line[1][0] <== line1[1][0];
        onSegment[i].line[1][1] <== line1[1][1];
        onSegment[i].point[0] <== line2[i][0];
        onSegment[i].point[1] <== line2[i][1];

        // Orientation with respect to line2
        orientation[i+2] = Orientation(grid_bits);
        // line2 point 1
        orientation[i+2].points[0][0] <== line2[0][0];
        orientation[i+2].points[0][1] <== line2[0][1];
        // line2 point 2
        orientation[i+2].points[1][0] <== line2[1][0];
        orientation[i+2].points[1][1] <== line2[1][1];
        // line1 point i
        orientation[i+2].points[2][0] <== line1[i][0];
        orientation[i+2].points[2][1] <== line1[i][1];

        // Point on line 2
        onSegment[i+2] = OnSegment(grid_bits);
        onSegment[i+2].line[0][0] <== line2[0][0];
        onSegment[i+2].line[0][1] <== line2[0][1];
        onSegment[i+2].line[1][0] <== line2[1][0];
        onSegment[i+2].line[1][1] <== line2[1][1];
        onSegment[i+2].point[0] <== line1[i][0];
        onSegment[i+2].point[1] <== line1[i][1];
    }

    // If both points of each line segments are on different sides (i.e., have different orientations wrt) the other line, the
    // line segments certainly intersect.
    // This expression is 0 (false) if the orientations of both points of either line segments are equal.
    signal general_intersection <== (orientation[0].out - orientation[1].out) * (orientation[2].out - orientation[3].out);

    // Handle special case: if a point is colinear with the other line, and it lies on that line, then the line segments intersect
    signal on_line_intersection[4];
    for (var i=0; i<4; i++) {
        on_line_intersection[i] <== orientation[i].out + onSegment[i].out;
    }
    signal sc1 <== on_line_intersection[0] * on_line_intersection[1];
    signal sc2 <== on_line_intersection[2] * on_line_intersection[3];
    signal not_special_case <== sc1 * sc2;

    // Final result
    component not_general_intersection = IsZero();
    not_general_intersection.in <== general_intersection;
    signal not_out <== not_general_intersection.out * not_special_case;

    component negate = IsZero();
    negate.in <== not_out;
    out <== negate.out;
}

/*
Returns 1 if the 3 points are arranged in a clockwise order,
0 if they are in a line, and 2 if they are in a counter-clockwise order.

We use the slopes of the lines (p0, p1) and (p1, p02) to determine the orientation.
If the first slope is greater it's clockwise, if the second is greater it's anticlockwise,
and if they're equal it's in a line.

The slope of (p0, p1) is (y1 - y0) / (x1 - x0), and the slope of (p1,  p2) is (y2 - y1) / (x2 - x1).
Therefore the following expression will be positive for clockwise etc:
    f = (y1 - y0) / (x1 - x0) - (y2 - y1) / (x2 - x1)
      = (y1 - y0) * (x2 - x1) - (y2 - y1) * (x1 - x0)

Note that f is in the range (-(2^grid_bits)^2, (2^grid_bits)^2), so we have to make sure 2^grid_bits^2 < 2^252 (since 2^252 < p), or we overflow.
So grid_bits <= 127
*/
template Orientation(grid_bits) {
    signal input points[3][2];
    signal output out;

    assert(grid_bits <= 126);

    // (y1 - y0) * (x2 - x1) - (y2 - y1) * (x1 - x0)
    signal part <== (points[1][1] - points[0][1]) * (points[2][0] - points[1][0]);
    signal f <== part - (points[2][1] - points[1][1]) * (points[1][0] - points[0][0]);
    
    // Find the sign of f
    component num2Bits = Num2Bits(254);
    num2Bits.in <== f;

    component isNegative = Sign();
    for (var i=0; i<254; i++) {
        isNegative.in[i] <== num2Bits.out[i];
    }
    
    // Find out whether f is 0
    component isZero = IsZero();
    isZero.in <== f;
    signal nonZero <== (isZero.out-1)*(-1);

    // Calculate the orientation
    // nonZero  | isNegative    | Orientation
    // 0        | 0             | 0
    // 0        | 1             | 0
    // 1        | 0             | 1
    // 1        | 1             | 2
    out <== nonZero*(isNegative.sign+1);

    // confirm that the output is of the correct form
    signal x <== out * (out - 1);
    x * (out - 2) === 0;
}

/*
Given 3 colinear points, the function checks if point lies on line segment line[0]line[1]
*/
template OnSegment(grid_bits) {
    signal input line[2][2];
    signal input point[2];
    signal output out;

    // order the x and y values
    component ordered_x = Order(grid_bits);
    ordered_x.in[0] <== line[0][0];
    ordered_x.in[1] <== line[1][0];

    component ordered_y = Order(grid_bits);
    ordered_y.in[0] <== line[0][1];
    ordered_y.in[1] <== line[1][1];

    // Check that the point is on the x-projection
    component aboveMinX = LessEqThan(grid_bits);
    aboveMinX.in[0] <== ordered_x.out[0];
    aboveMinX.in[1] <== point[0];

    component belowMaxX = LessEqThan(grid_bits);
    belowMaxX.in[0] <== point[0];
    belowMaxX.in[1] <== ordered_x.out[1];

    signal on_x_projection <== aboveMinX.out * belowMaxX.out;

    // Check that the point is on the y-projection
        component aboveMinY = LessEqThan(grid_bits);
    aboveMinY.in[0] <== ordered_y.out[0];
    aboveMinY.in[1] <== point[1];

    component belowMaxY = LessEqThan(grid_bits);
    belowMaxY.in[0] <== point[1];
    belowMaxY.in[1] <== ordered_y.out[1];

    signal on_y_projection <== aboveMinY.out * belowMaxY.out;

    // return whether the point is on both the x and y projections
    out <== on_x_projection * on_y_projection;

    // make sure the output is 0 or 1
    out * (out - 1) === 0;
}

/*
Return two values in order
*/
template Order(grid_bits) {
    signal input in[2];
    signal output out[2];

    component lt = GreaterThan(grid_bits);
    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    out[0] <== (in[1] - in[0])*lt.out + in[0];
    out[1] <== (in[0] - in[1])*lt.out + in[1];
}

/*
Returns 1 if a polygon is simple and non-degenerate, 0 otherwise.
*/
template SimplePolygon(n, grid_bits) {
    signal input polygon[n][2];
    signal output out;

    // Make sure none of the lines intersect, except two adjacent lines, where we just require that p3 can't be on the segment p1p2
}

// From https://docs.circom.io/more-circuits/more-basic-circuits/#extending-our-multiplier-to-n-inputs
template MultiplierN (N){
   //Declaration of signals.
   signal input in[N];
   signal output out;
   component comp[N-1];

   //Statements.
   for(var i = 0; i < N-1; i++){
       comp[i] = Multiplier2();
   }
   comp[0].in1 <== in[0];
   comp[0].in2 <== in[1];
   for(var i = 0; i < N-2; i++){
       comp[i+1].in1 <== comp[i].out;
       comp[i+1].in2 <== in[i+2];

   }
   out <== comp[N-2].out; 
}

template Multiplier2() {
    signal input in1;
    signal input in2;
    signal output out;
    out <== in1*in2;
 }