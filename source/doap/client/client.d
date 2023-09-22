module doap.client.client;

import std.socket : Socket, Address, SocketType, ProtocolType, getAddress, parseAddress, InternetAddress, SocketShutdown;
import doap.client.messaging : CoapMessagingLayer;
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
    private Address address;

    /** 
     * Running status
     */
    package bool running;

    /** 
     * The datagram socket
     */
    package Socket socket;

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
     * Creates a new CoAP client to the
     * provided endpoint address
     *
     * Params:
     *   address = the CoAP server endpoint
     */
    this(Address address)
    {
        this.address = address;
        this.messaging = new CoapMessagingLayer(this);

        this.requestsLock = new Mutex();
        this.watcherSignal = new Condition(this.requestsLock);

        init();
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
        // TODO: IF connect fails then don't start messaging
        this.socket = new Socket(this.address.addressFamily(), SocketType.DGRAM, ProtocolType.UDP);
        // this.socket.blocking(true);
        this.socket.connect(address);

        // Set status to running
        this.running = true;



        // Start the messaging layer
        this.messaging.start();
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

        // Shutdown the socket (stopping the messaging layer)
        this.socket.shutdown(SocketShutdown.BOTH);

        // Unbind (disallow incoming datagrams to source port (from device))
        this.socket.close();
        
        // TODO: We must wake up other sleeprs with an error
        // (somehow, pass it in, flag set)
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
     * request with a matching token and return it
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
        this.socket.send(request.getRequestPacket().getBytes());

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