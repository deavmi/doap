module doap.client.exceptions;

import doap.exceptions : CoapException;
import core.time : Duration;

public class CoapClientException : CoapException
{
    this(string msg)
    {
        super(msg);
    }
}

import doap.client.request : CoapRequestFuture;
import std.conv : to;

package final class RequestTimeoutException : CoapClientException
{
    /** 
     * The future we timed out on
     */
    private CoapRequestFuture future;

    /**
     * Timeout time
     */
    private Duration timeout;

    /** 
     * Constructs a new timeout exception for
     * the given future which timed out
     *
     * Params:
     *   future = the future we timed out on
     *   timeout = the time duration timed out
     * on
     */
    this(CoapRequestFuture future, Duration timeout)
    {
        super("Timed out whilst waiting for "~to!(string)(future)~" after "~to!(string)(timeout));
        this.future = future;
        this.timeout = timeout;
    }
}