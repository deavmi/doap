/**
 * Utility functions
 */
module doap.utils;

/** 
 * Flips the given integral value
 *
 * Params:
 *   bytesIn = the integral value
 * Returns: the flipped integral
 */
public T flip(T)(T bytesIn) if(__traits(isIntegral, T))
{
    T copy = bytesIn;

    ubyte* base = (cast(ubyte*)&bytesIn)+T.sizeof-1;
    ubyte* baseCopy = cast(ubyte*)&copy;

    for(ulong idx = 0; idx < T.sizeof; idx++)
    {
        *(baseCopy+idx) = *(base-idx);
    }

    return copy;
}

/** 
 * Ordering
 */
public enum Order
{
    /**
     * Little endian
     */
    LE,

    /**
     * Big endian
     */
    BE
}

/** 
 * Swaps the bytes to the given ordering but does a no-op
 * if the ordering requested is the same as that of the 
 * system's
 *
 * Params:
 *   bytesIn = the integral value to swap
 *   order = the byte ordering to request
 * Returns: the integral value
 */
public T order(T)(T bytesIn, Order order) if(__traits(isIntegral, T))
{
    version(LittleEndian)
    {
        if(order == Order.LE)
        {
            return bytesIn;
        }
        else
        {
            return flip(bytesIn);
        }
    }
    else version(BigEndian)
    {
        if(order == Order.BE)
        {
            return bytesIn;
        }
        else
        {
            return flip(bytesIn);
        }
    }
}


version(unittest)
{
    import std.stdio : writeln;
}

unittest
{
    version(LittleEndian)
    {
        ushort i = 1;
        writeln("Pre-order: ", i);
        ushort ordered = order(i, Order.BE);
        writeln("Post-order: ", ordered);
        assert(ordered == 256);
    }
    else version(BigEndian)
    {
        // TODO: Add this AND CI tests for it
    }
   
}

/** 
 * Checks if the given value is present in
 * the given array
 *
 * Params:
 *   array = the array to check against
 *   value = the value to check prescence
 * for
 * Returns: `true` if present, `false`
 * otherwise
 */
public bool isPresent(T)(T[] array, T value)
{
    if(array.length == 0)
    {
        return false;
    }
    else
    {
        foreach(T cur; array)
        {
            if(cur == value)
            {
                return true;
            }
        }

        return false;
    }
}

unittest
{
    ubyte[] values = [1,2,3];
    foreach(ubyte value; values)
    {
        assert(isPresent(values, value));
    }
    assert(isPresent(values, 0) == false);
    assert(isPresent(values, 5) == false);
}

/** 
 * Given an array of values this tries to find
 * the next free value of which is NOT present
 * within the given array
 *
 * Params:
 *   used = the array of values
 * Returns: the free value
 */
public T findNextFree(T)(T[] used) if(__traits(isIntegral, T))
{
    T found;
    if(used.length == 0)
    {
        return 0;
    }
    else
    {
        found = 0;
        while(isPresent(used, found)) // FIXME: Constant loop if none available
        {
            found++;
        }

        return found;
    }
}

unittest
{
    ubyte[] values = [1,2,3];
    ubyte free = findNextFree(values);
    assert(isPresent(values, free) == false);
}