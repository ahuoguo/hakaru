# Arrays and Plate

Hakaru provides special syntax for arrays, which
is distinct from the other data types.

## Arrays

To construct arrays, we provide an index variable, size argument, and
an expression body. This body is evaluated for each index of the
array. For example, to construct the array `[0,1,2,3]`:

````nohighlight
array i of 4: i
````

### Array Literals

We can also create arrays using the literal syntax a comma delimited
list surrounded by brackets: `[0,1,2,3]`

### Array size and indexing

If `a` is an array, then `size(a)` is its number of elements, which is a `nat`.
If `i` is a `nat` then `a[i]` is the element of `a` at index `i`.
Indices start at zero, so the maximum valid value of `i` is `size(a)-1`.

## Plate

Beyond, arrays Hakaru includes special syntax for describing measures
over arrays called `plate`. Plate using the same syntax as `array` but
the body must have a measure type. It returns a measure over arrays.
For example, if we wish to have a distribution over three independent
normal distributions we would do so as follows:

````nohighlight
plate _ of 3: normal(0,1)
````
