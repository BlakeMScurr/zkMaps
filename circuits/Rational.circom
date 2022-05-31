pragma circom 2.0.0;

/*

Represents rational numbers of arbitrary precision

Addition, Subtraction, Division, Multiplication
Comparison
Casting to higher precision

TODO: figure out a casting algorithm. There may be some kind of oracle based technique.
Suppose you want to prove that a_1*a_2*...*a_n/b_1*b_2*...*b_n < c_1*c_2*...*c_n/d_1*d_2*...*d_n.
Then the oracle defines how to add to a_i and simplify a_i/b_i and how to subtract from c_i and simplify c_i/d_i.
If we can simplify enough, each b_i is equal to some d_j, and we can directly compare a_i and c_j.

The nuances with this algorithm is that it can't necessarily prove all actual inequalities, and we may need more complex oracles
to cover more cases. Further, we need to make sure adding, subtracting, simplifying etc don't wrap around.

*/