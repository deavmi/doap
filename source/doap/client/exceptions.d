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

public final class RequestTimeoutException : CoapClientException
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
    package this(CoapRequestFuture future, Duration timeout)
    {
        super("Timed out whilst waiting for "~to!(string)(future)~" after "~to!(string)(timeout));
        this.future = future;
        this.timeout = timeout;
    }

    /** 
     * Returns the future request which timed
     * out and cause dthis exception to throw
     * in the first place
     *
     * Returns: the `CoapRequestFuture`
     */
    public CoapRequestFuture getFuture()
    {
        return this.future;
    }

    /** 
     * Returns the timeout period which 
     * was exceeded
     *
     * Returns: the `Duration`
     */
    public Duration getTimeout()
    {
        return this.timeout;
    }
}