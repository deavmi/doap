module doap.client.client;

import std.socket : Socket, Address, SocketType, ProtocolType, getAddress, parseAddress, InternetAddress, SocketShutdown;
import doap.client.messaging;
import doap.protocol;
import doap.client.request : CoapRequestBuilder, CoapRequest, CoapRequestFuture;
import core.sync.mutex : Mutex;
import core.sync.condition : Condition;
import std.container.slist : SList;
import core.thread : dur, Duration, Thread;

/** 
 * A CoAP client
 */
public class CoapClient
{
    /** 
     * CoAP server endpoint
     */
    package Address address;

    /** 
     * Running status
     */
    package bool running;

    /** 
     * The messaging layer which provides
     * request-response message match-ups
     */
    private CoapMessagingLayer messaging;

    /** 
     * The request-response match list
     */
    private SList!(CoapRequest) outgoingRequests;

    /** 
     * The lock for the request-response match list
     */
    private Mutex requestsLock;

    /** 
     * Condition variable for watcher signalling
     */
    private Condition watcherSignal;

    /**
     * Rolling Message ID
     */
    private ushort rollingMid;
    private Mutex rollingLock;

    /** 
     * Creates a new CoAP client to the
     * provided endpoint address
     *
     * Params:
     *   address = the CoAP server endpoint
     */
    this(Address address)
    {
        this.address = address;

        import doap.client.messaging.udp : UDPMessaging;
        this.messaging = new UDPMessaging(this); //UDP transport

        this.requestsLock = new Mutex();
        this.watcherSignal = new Condition(this.requestsLock);

        this.rollingMid = 0;
        this.rollingLock = new Mutex();

        init();
    }

    package ushort newMid()
    {
        ushort newValue;

        // Lock rolling counter
        this.rollingLock.lock();

        newValue = this.rollingMid;
        this.rollingMid++;

        // Unlock rolling counter
        this.rollingLock.unlock();

        return newValue;
    }

    /** 
     * Constructs a new CoAP client to the
     * provided endpoint address and port.
     *
     * This constructor provided name
     * resolution on the host part.
     *
     * Params:
     *   host = the CoAP host
     *   port = the CoAP port
     */
    this(string host, ushort port)
    {
        this(new InternetAddress(host, port));
    }

    /** 
     * Sets up a new datagram socket,
     * sets the running status to `true`
     * and then starts the messaging
     * layer
     */
    private void init()
    {
        // Set status to running
        this.running = true;

        // Start the messaging layer
        this.messaging.begin();
    }

    /** 
     * Stops this client
     *
     * This results in closing down the
     * messaging layer and ensuring that
     * no new datagrams may arrive on
     * our source port.
     */
    public void close()
    {
        // Set status to not running
        this.running = false;

        // Shutdown the messaging layer
        this.messaging.close();
        
        // Cancel all active request futures
        this.requestsLock.lock();
        foreach(CoapRequest curReq; outgoingRequests)
        {
            curReq.future.cancel();
        }
        this.requestsLock.unlock();
    }

    /** 
     * Creates a new CoAP request builder
     *
     * Returns: a new `CoapRequestBuilder`
     */
    public CoapRequestBuilder newRequestBuilder()
    {
        return new CoapRequestBuilder(this);
    }

    /** 
     * Given the builder this will extract the details required
     * to encode the CoAP packet into its byte form, register
     * a coap request internally and return a future for this
     * request.
     *
     * Params:
     *   requestBuilder = the request builder
     * Returns: the future
     */
    package CoapRequestFuture doRequest(CoapRequestBuilder requestBuilder)
    {
        // Encode the packet
        CoapPacket requestPacket = new CoapPacket();
        requestPacket.setCode(requestBuilder.requestCode);
        requestPacket.setPayload(requestBuilder.pyld);
        requestPacket.setToken(requestBuilder.tkn);
        requestPacket.setMessageId(newMid());

        // Create the future
        CoapRequestFuture future = new CoapRequestFuture();

        // Link the CoapRequest to the future so it can be signalled
        CoapRequest request = new CoapRequest(requestPacket, future);

        // Store the request
        storeRequest(request);

        // Transmit the request
        transmitRequest(request);

        return future;
    }

    /** 
     * Stores the request
     *
     * Params:
     *   request = the `CoapRequest` to store in the
     * tracking list
     */
    private void storeRequest(CoapRequest request)
    {
        // Store the request
        requestsLock.lock();
        outgoingRequests.insertAfter(outgoingRequests[], request);
        requestsLock.unlock();
    }

    /** 
     * Given a token this will try and find an active
     * request with a matching token and return it.
     *
     * This will also remove it from the requests queue.
     *
     * Params:
     *   token = the token
     * Returns: the original `CoapRequest` if a match
     * is found, otherwise `null`
     */
    package CoapRequest yankRequest(ubyte[] token)
    {
        CoapRequest foundRequest = null;

        requestsLock.lock();

        foreach(CoapRequest request; outgoingRequests)
        {
            if(request.getToken() == token)
            {
                foundRequest = request;
                outgoingRequests.linearRemoveElement(foundRequest);
                break;
            }
        }

        requestsLock.unlock();

        return foundRequest;
    }

    /** 
     * Transmits the given request's associated
     * packet to the underlying transport
     *
     * Params:
     *   request = the `CoapRequest` to put into
     * flight
     */
    private void transmitRequest(CoapRequest request)
    {
        // Encode the request packet and send it
        this.messaging.send(request.getRequestPacket());

        // Now start ticking the timer
        request.startTime();
    }

    // private Duration sweepInterval;
    private Duration retransmitTimeout;

    /** 
     * The intention of this method is that
     * some kind-of `CoapMessagingLayer`
     * can call this when it has no new
     * messages to process.
     *
     * This then let's the client handle
     * the checking of potentially timed
     * out requests, and the re-issueing
     * of them to the messaging layer.
     */
    package void onNoNewMessages()
    {
        requestsLock.lock();
        foreach(CoapRequest curReq; outgoingRequests)
        {
            if(curReq.hasTimedOut(retransmitTimeout))
            {
                // TODO: Retransmit
            }
        }
        requestsLock.unlock();
    }
}

/**
 * Tests the client
 *
 * In the future dogfooding should be
 * used and we should test against our
 * own server too.
 */
unittest
{
    // Address[] resolved = getAddress("coap.me");
    // resolved[0].po
    Address addr = new InternetAddress("coap.me", 5683);
    // CoapClient client = new CoapClient(addr);

    // client.resource("/hello");

    // client.connect();

    // Test sending something
    CoapPacket packet = new CoapPacket();
    packet.setCode(Code.POST);
    packet.setToken([69]);
    packet.setPayload(cast(ubyte[])"My custom payload");
    packet.setType(MessageType.CONFIRMABLE);
    packet.setMessageId(257);

    // client.socket.send(packet.getBytes());

}

version(unittest)
{
    import std.stdio : writeln;
}

/**
 * Client testing
 *
 * This tests building of a request using the builder,
 * finalizing through the client and then waiting on
 * the returned future for a result.
 *
 * We test the blocking example here therefore, i.e.
 * a blocking `get()`.
 *
 * This therefore tests the entire `messaging` module
 * and `client` module.
 */
unittest
{
    CoapClient client = new CoapClient("coap.me", 5683);

    
    CoapRequestFuture future = client.newRequestBuilder()
                              .payload(cast(ubyte[])"Hello this is Tristan!")
                              .token([69])
                              .post();


    writeln("Future start");
    CoapPacket response  = future.get();
    writeln("Future done");
    writeln("Got response: ", response);

    client.close();
}

version(unittest)
{
    import core.time : dur;
    import doap.client.exceptions : RequestTimeoutException;
    import doap.client.request : CoapRequestFuture, RequestState;
}

/**
 * Client testing
 *
 * See above except we test a timeout-based
 * request future here.
 *
 * This test DOES time out
 */
unittest
{
    CoapClient client = new CoapClient("coap.me", 5683);

    
    CoapRequestFuture future = client.newRequestBuilder()
                              .payload(cast(ubyte[])"Hello this is Tristan!")
                              .token([69])
                              .post();

    try
    {
        writeln("Future start");
        CoapPacket response  = future.get(dur!("msecs")(10));

        // We should timeout and NOT get here
        assert(false);
    }
    catch(RequestTimeoutException e)
    {
        // Ensure that we have the correct state
        assert(future.getState() == RequestState.TIMEDOUT);

        // We SHOULD time out
        assert(true);
    }

    client.close();
}

/**
 * Client testing
 *
 * See above except we test a timeout-based
 * request future here.
 *
 * This test DOES NOT time out (it tests
 * with a high-enough threshold)
 */
unittest
{
    CoapClient client = new CoapClient("coap.me", 5683);

    
    CoapRequestFuture future = client.newRequestBuilder()
                              .payload(cast(ubyte[])"Hello this is Tristan!")
                              .token([69])
                              .post();

    try
    {
        writeln("Future start");
        CoapPacket response  = future.get(dur!("msecs")(400));

        // Ensure that we have the correct state
        assert(future.getState() == RequestState.COMPLETED);

        // We SHOULD get here
        assert(true);
    }
    catch(RequestTimeoutException e)
    {
        // We should NOT time out
        assert(false);
    }

    client.close();
}