module doap.client.request;

import doap.client.client : CoapClient;
import doap.protocol;
import doap.exceptions;

/**
 * Represents a request that has been made. This is
 * normally stored inside the `CoapClient` and used
 * to find matching responses that come through in
 * the messaging layer.
 *
 * It is composed of the `token` and the future
 * which was created. Therefore when the messaging
 * layer receives a new CoAP packet it can then try
 * match it to one of these requests, in the event
 * it finds a match it can retrieve the future, place
 * the received `CoapPacket` into it and then wake up
 * anyone doing a blocking `get()` on it.
 */
package class CoapRequest
{
    /** 
     * The token to be able to match a response
     * to
     */
    package ubyte[] token;

    /** 
     * The future which we can fill up with the
     * response and then wake up the receiver
     */
    package CoapRequestFuture future;

    /** 
     * Constructs a new request
     *
     * Params:
     *   token = the token
     *   future = the `CoapRequestFuture` to wake up
     * on data arrival
     */
    this(ubyte[] token, CoapRequestFuture future)
    {
        this.token = token;
        this.future = future;
    }
}

/** 
 * This allows one to build up a new
 * CoAP request of some form in a 
 * method-call-by-method-call manner.
 *
 * In order to instantiate one of these
 * please do so via the `CoapClient`.
 */
package class CoapRequestBuilder
{
    /** 
     * The associated client for
     * making the actual request
     */
    private CoapClient client;

    /** 
     * The request code
     */
    package Code requestCode;

    /** 
     * The payload
     */
    package ubyte[] pyld;

    /** 
     * The token
     */
    package ubyte[] tkn;

    /** 
     * Constructs a new builder
     *
     * This requires a working `CoapClient`
     * such that finalization can be done
     * on its side
     *
     * Params:
     *   client = the client to associate with
     */
    this(CoapClient client)
    {
        this.client = client;
        this.requestCode = Code.GET;
    }

    /** 
     * Set the payload for this request
     *
     * Params:
     *   payload = the payload
     * Returns: this builder
     */
    public CoapRequestBuilder payload(ubyte[] payload)
    {
        this.pyld = payload;
        return this;
    }

    /** 
     * Set the token to use for this request
     *
     * Params:
     *   tkn = the token
     * Returns: this builder
     */
    public CoapRequestBuilder token(ubyte[] tkn)
    {
        if(tkn.length > 8)
        {
            throw new CoapException("The token cannot be more than 8 bytes");
        }

        this.tkn = tkn;
        return this;
    }

    /** 
     * Build the request, set it in flight
     * and return the future handle to it.
     *
     * This sets the request code to POST.
     *
     * Returns: the `CoapRequestFuture` for
     * this request
     */
    public CoapRequestFuture post()
    {
        // Set the request code to POST
        this.requestCode = Code.POST;

        // Register the request via the client
        // ... and obtain the future
        return this.client.doRequest(this);
    }

    /** 
     * Build the request, set it in flight
     * and return the future handle to it.
     *
     * This sets the request code to GET.
     *
     * Returns: the `CoapRequestFuture` for
     * this request
     */
    public CoapRequestFuture get()
    {
        // Set the request code to GET
        this.requestCode = Code.GET;

        // Register the request via the client
        // ... and obtain the future
        return this.client.doRequest(this);
    }
}

import core.sync.mutex : Mutex;
import core.sync.condition : Condition;

/** 
 * This is returned to the user when he
 * does a finalizing call on a `CoapRequestBuilder`
 * such as calling `post()`. The client
 * will then creating the underlying request
 * such that the messaging layer can match
 * a future response to it. The client then
 * sends the CoAP packet and then returns
 * this so-called "future" as a handle
 * to it which can be waited on via
 * a call to `get()`.
 */
public class CoapRequestFuture
{
    /** 
     * The received response
     *
     * This is filled in by the
     * messaging layer.
     */
    private CoapPacket response;

    /** 
     * Mutex (for the condition to use)
     */
    private Mutex mutex;

    /** 
     * Condition variable
     *
     * Used for doing `wait()`/`notify()`
     * such that the messaging layer can
     * wake up a sleeping/blocking `get()`
     */
    private Condition condition;

    /** 
     * Constructs a new `CoapRequestFuture`
     */
    package this()
    {
        this.mutex = new Mutex();
        this.condition = new Condition(mutex);
    }

    /** 
     * Called when a matching (by token) CoAP packet
     * is received. This will store the received response
     * and also wake up anyone blocking on the `get()`
     * call to this future.
     *
     * Params:
     *   response = the `CoapPacket` response
     */
    package void receiveWake(CoapPacket response)
    {
        // Set the received response
        this.response = response;

        // Wake up the sleepers
        this.condition.notify();
    }

    /** 
     * Blocks until the response is received
     *
     * Returns: the response as a `CoapPacket`
     */
    public CoapPacket get()
    {
        // We can only wait on a condition if we
        // ... first have a-hold of the lock
        this.mutex.lock();

        // Await a response
        this.condition.wait();

        // Upon waking up release lock
        this.mutex.unlock();

        return this.response;
    }

}