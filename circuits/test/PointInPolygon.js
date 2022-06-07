const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
chai.should();

const path = require("path");

const wasm_tester = require("circom_tester").wasm;

const F1Field = require("ffjavascript").F1Field;
const Scalar = require("ffjavascript").Scalar;
exports.p = Scalar.fromString("21888242871839275222246405745257275088548364400416034343698204186575808495617");
const Fr = new F1Field(exports.p);

const assert = chai.assert;

describe("Multiplier5", function () {
    this.timeout(100000000);

    var circuit;
    this.beforeAll(async () => {
        var filepath = path.join(__dirname, "Multiplier5.circom")
        circuit = await wasm_tester(filepath);
        await circuit.loadConstraints();
        assert.equal(circuit.constraints.length, 4); // TODO: verify that this is expected
    })

    it("Should give the product of 5 numbers", async () => {
        var witness = await circuit.calculateWitness({ "in": [1,2,3,4,5] }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(1*2*3*4*5)));
    })
})

describe("Intersects", function () {
    this.timeout(100000000);

    var circuit;
    this.beforeAll(async () => {
        var filepath = path.join(__dirname, "Intersects.circom")
        circuit = await wasm_tester(filepath);
        await circuit.loadConstraints();
        // assert.equal(circuit.constraints.length, 2929); // TODO: verify that this is expected
    })

    var test_transformations = async (cases, result) => {
        for (let i = 0; i < cases.length; i++) {
            const c = cases[i];
            var witness = await circuit.calculateWitness({ "line1": c[0], "line2": c[1] }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

            // flip order
            var witness = await circuit.calculateWitness({ "line1": c[1], "line2": c[0] }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

            // flip coordinates
            var witness = await circuit.calculateWitness({ "line1": [c[0][1], c[0][0]], "line2": [c[1][1], c[1][0]] }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));
        }
    }

    it("Should recognise basic intersections", async () => {
        var cases = [
            [
                [[0,0],[1,1]],
                [[1,0], [0,1]],
            ],
            [
                [[0,0],[10,10]],
                [[1,0], [0,1]],
            ],
            [
                [[0,10], [10,10]],
                [[5,0], [5,15]],
            ]
        ]

        await test_transformations(cases, 1)
    })

    it("Should recognise non intersections", async () => {
        var cases = [
            // diagonal lines
            [
                // parallel
                [[0,0],[1,1]], 
                [[0,1], [1,2]],
            ],
            [
                // t-shaped
                [[0,0],[1,1]],
                [[1,2], [2,1]],
            ],
            // horizontal first line
            [
                // parallel
                [[0,10],[10,10]],
                [[0,0], [10,0]],
            ],
            [
                // t-shaped
                [[0,10], [10,10]],
                [[11,0], [11,15]],
            ]
        ]
        await test_transformations(cases, 0)
    })

    it("Should recognise edge cases where we're on the line segment", async () => {
        cases = [
            // Diagonal
            [
                // Not collinear
                [[0,0], [5,5]],
                [[3,3], [5234,43]],
            ],
            [
                // Collinear
                [[0,0], [5,5]],
                [[3,3], [100,100]],
            ],
            // Horizontal
            [
                // Not collinear
                [[0,10],[10,10]],
                [[5,10], [2435,543]],
            ],
            [
                // Collinear
                [[0,10],[10,10]],
                [[5,10], [2435,10]],
            ],
        ]
        await test_transformations(cases, 1)
    })

    it("Should reject collinear cases where we're not on the line segment", async () => {
        cases = [
            // Diagonal
            [
                [[0,0], [5,5]],
                [[6,6], [7,7]],
            ],
            // Horizontal
            [
                [[0,10],[10,10]],
                [[11,10], [2435,10]],
            ],
        ]
        await test_transformations(cases, 1)
    })
})

describe("OnSegment", function () {
    this.timeout(100000000);

    var circuit;
    this.beforeAll(async () => {
        var filepath = path.join(__dirname, "OnSegment.circom")
        circuit = await wasm_tester(filepath);
        await circuit.loadConstraints();
        assert.equal(circuit.constraints.length, 206); // TODO: verify that this is expected
    })

    var line = [[5,5], [10,10]]
    it("Should accpet when the point is on both projections", async () => {
        var points = [
            [5,5],
            [5,7],
            [5,10],
            
            [7,5],
            [7,7],
            [7,10],
            
            [10,5],
            [10,7],
            [10,10],
        ]

        for (let i=0; i < points.length; i++) {
            const point = points[i];
            var witness = await circuit.calculateWitness({ "line": line, "point": point }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(1)));
        }
    })

    it("Should reject when the point is on neither projection", async () => {
        var points = [
            [0,0],
            [4,4],
            [11,11],
            [1000,1000],
            [4,11],
            [11,4],
        ]

        for (let i=0; i < points.length; i++) {
            const point = points[i];
            var witness = await circuit.calculateWitness({ "line": line, "point": point }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(0)));
        }
    })

    it("Should reject when the point is on one projection but not the other", async () => {
        var points = [
            [0,5],
            [0,7],
            [0,10],

            [4,5],
            [4,7],
            [4,10],

            [11,5],
            [11,7],
            [11,10],
        ]

        for (let i=0; i < points.length; i++) {
            const point = points[i];
            var witness = await circuit.calculateWitness({ "line": line, "point": point }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(0)));

            // reverse x and y
            var witness = await circuit.calculateWitness({ "line": line, "point": [point[1], point[0]] }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(0)));
        }
    })
})

describe("Order", function () {
    this.timeout(100000000);

    var circuit;
    this.beforeAll(async () => {
        var filepath = path.join(__dirname, "Order.circom")
        circuit = await wasm_tester(filepath);
        await circuit.loadConstraints();
        assert.equal(circuit.constraints.length, 35); // TODO: verify that this is expected
    })

    it("Should return values in order", async () => {
        var cases = [
            [1234, 43],
            [84, 44],
            [0, 433],
            [0,0],
            [12,12],
        ]

        for (let i=0; i < cases.length; i++) {
            const c = cases[i];
            var witness = await circuit.calculateWitness({ "in": [c[0], c[1]] }, true);
            assert(Fr.eq(Fr.e(witness[1]), Fr.e(Math.min(c[0], c[1]))));
            assert(Fr.eq(Fr.e(witness[2]), Fr.e(Math.max(c[0], c[1]))));
        }
    })
})

describe("Orientation", function () {
    this.timeout(100000000);

    var circuit;
    this.beforeAll(async () => {
        var filepath = path.join(__dirname, "Orientation.circom")
        circuit = await wasm_tester(filepath);
        await circuit.loadConstraints();
        assert.equal(circuit.constraints.length, 523); // TODO: verify that this is expected
    })

    var transform = (points, plusX, plusY, timesX, timesY) => {
        return points.map((p)=>{
            return [(p[0]+plusX)*timesX, (p[1]+plusY)*timesY]
        })
    }

    // Tests an individual triplet
    var t = async (a,b,c, result) => {
        var ps = [a,b,c]
        var witness = await circuit.calculateWitness({ "points": ps }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

        // stretches all the points times 10 in the x and y directions and makes sure the result still holds
        var witness = await circuit.calculateWitness({ "points": transform(ps, 0, 0, 10, 1) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));
        
        var witness = await circuit.calculateWitness({ "points": transform(ps, 0, 0, 1, 10) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

        var witness = await circuit.calculateWitness({ "points": transform(ps, 0, 0, 10, 10) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

        // adds 10 to x and/or y and makes sure the result still holds
        var witness = await circuit.calculateWitness({ "points": transform(ps, 10, 0, 1, 1) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

        var witness = await circuit.calculateWitness({ "points": transform(ps, 0, 10, 1, 1) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));

        var witness = await circuit.calculateWitness({ "points": transform(ps, 10, 10, 1, 1) }, true);
        assert(Fr.eq(Fr.e(witness[1]), Fr.e(result)));
    }

    it("Should get the right orientation for sloped lines", async () => {
        // (a,b) is the line y=x
        var a = [0,0]
        var b = [5,5]
    
        // Build up our cases
        var clockwise = [
            [5,0,1],
            [1,0,1],
            [10,0,1],
            [10,9,1],
        ]
        var counterclockwise = clockwise.map(p => [p[1], p[0], 2]) // swap x and y, i.e., mirror across y=x and expect counterclockwise result
        var collinear = [
            [0,0, 0],
            [1,1, 0],
            [10,10, 0],
        ]
        var cases = clockwise.concat(counterclockwise, collinear)

        for (var i=0; i<cases.length; i++) {
            await t(a,b,[cases[i][0], cases[i][1]], cases[i][2]);
        }

        // try a downward sloped line
        // i.e., negate the x coordinate (and add 20 to make sure we're positive), and expect inverted results
        for (var i=0; i<cases.length; i++) {
            await t(
                [20 - a[0], a[1]],
                [20 - b[0], b[1]],
                [
                    20-cases[i][0],
                    cases[i][1],
                ],
                [0,2,1][cases[i][2]],
        );
        }
    })

    it("Should get the right orientation for flat lines", async () => {
        // (a,b) is the line y=5
        var a = [0,5]
        var b = [5,5]
        var clockwise = [
            [0,0],
            [5,0],
            [10, 0],
            [10, 4]
        ]

        for (var i=0; i<clockwise.length; i++) {
            await t(a,b,clockwise[i], 1); // Clockwise
            await t(a,b, [clockwise[i][0], 10 - clockwise[i][1]], 2); // Counterclockwise (note, f(y) = 10-y flips y about the line y=5)
            
            // swap x and y for vertical lines
        }
    })
})