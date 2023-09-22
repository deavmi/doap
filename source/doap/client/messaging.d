module doap.client.messaging;

import doap.client.client : CoapClient;
import core.thread : Thread;
import std.socket : SocketFlags;
import core.sys.posix.sys.socket : MSG_TRUNC;
import doap.protocol;
import doap.exceptions;
import doap.client.request : CoapRequest;

import std.stdio;

import std.socket : Socket, SocketSet;
import std.socket : Address;

import std.socket : Socket, Address, SocketType, ProtocolType, getAddress, parseAddress, InternetAddress, SocketShutdown;

// TODO: Generalize this and then make
// ... a UDP version of it

/**
 * Stateful management of responses for
 * previously made requests.
 *
 * Handles the actual sending and receiving
 * of datagrams and fulfilling of requests
 */
class CoapMessagingLayer : Thread
{
    /** 
     * The client
     */
    private CoapClient client;

    /** 
     * Running status
     */
    private bool running;

    /** 
     * The datagram socket
     */
    private Socket socket;

    /** 
     * Constructs a new messaging layer instance
     * associated with the provided client
     *
     * Params:
     *   client = the client
     */
    this(CoapClient client)
    {
        super(&loop);
        this.client = client;
    }

    /** 
     * Retrieves the CoAP endpoint the client is
     * connected to
     *
     * Returns: the endpoint address
     */
    protected final Address getEndpointAddress() // Final in Interface
    {
        return this.client.address;
    }

    public void begin() // Candidate for Interface
    {
        // TODO: Handle socket errors nicely?

        // Set status to running
        this.running = true;


        // TODO: IF connect fails then don't start messaging
        this.socket = new Socket(getEndpointAddress().addressFamily(), SocketType.DGRAM, ProtocolType.UDP);
        // this.socket.blocking(true);
        this.socket.connect(getEndpointAddress());


        // Start the thread (TODO: In future hide threading)
        this.start();
    }

    public void send(CoapPacket packet) // Candidate for Interface
    {
        // Encode the packet and send the bytes
        ubyte[] encodedPacket = packet.getBytes();
        this.socket.send(encodedPacket);
    }

    public void close() // Candidate for Interface
    {
        // Set status to not running
        this.running = false;

        // Shutdown the socket (stopping the messaging layer)
        this.socket.shutdown(SocketShutdown.BOTH);

        // Unbind (disallow incoming datagrams to source port (from device))
        this.socket.close();

        // Wait till the reading-loop thread exits
        this.join();
    }

    /** 
     * Reading loop which reads datagrams
     * from the socket
     */
    private void loop()
    {
        // TODO: Ensure below condition works well
        while(this.client.running)
        {
            writeln("h");


            // TODO: Add select here, if readbale THEN do the below
            /** 
             * TODO: Add a call to select(), if NOTHING is available
             * then call the client's `onNoNewMessages()`.
             *
             * After this do a timed `receive()` below (this is where
             * the thread gets some rest by doing a timed I/O wait).
             *
             * Recall, however, we don't want to wait forever, as
             * we may now have elapsed over a request time-out
             * for a CoapRequest and should loop back to the top
             * to call `onNoNewMessages()`
             */
            // SocketSet readSet = new SocketSet();
            // readSet.add(this.client.socket);
            // Socket.select(readSet, null, null);

            // If there is NOT data available
            // if(!readSet.isSet(this.client.socket))
            // {
                // writeln("No data available");

                // TODO: Implement me
            // }
            




            // TODO: Check if socket is readable, if not,
            // ... check timers on outstanding messages
            // ... and do any resends needed
            SocketFlags flags = cast(SocketFlags)(SocketFlags.PEEK | MSG_TRUNC);
            byte[] data;
            data.length = 1; // At least one else never does underlying recv()
            ptrdiff_t dgramSize = this.socket.receive(data, flags);
            
            // If we have received something then dequeue it of the peeked length
            if(dgramSize > 0)
            {
                data.length = dgramSize;
                this.socket.receive(data);
                writeln("received size: ", dgramSize);
                writeln("received bytes: ", data);

                try
                {
                    CoapPacket receivedPacket = CoapPacket.fromBytes(cast(ubyte[])data);
                    writeln("Incoming coap packet: ", receivedPacket);

                    handlePacket(receivedPacket);
                }
                catch(CoapException e)
                {
                    writeln("Skipping malformed coap packet");
                }
            }
        }
    }

    /** 
     * Processes a decoded packet. How this is
     * handled depends on the type of packet
     * received. Normally this means matching
     * it up with a current `CoapRequest`
     * present in the `CoapClient`, fulling
     * it up with the received packet and
     * waking it (handled in the client code).
     *
     * Params:
     *   packet = the packet to process
     */
    private void handlePacket(CoapPacket packet)
    {
        CoapRequest request = this.client.yankRequest(packet.getToken());
        if(request)
        {
            writeln("Matched response '"~packet.toString()~"' to request '"~request.toString()~"'");
            writeln("Elapsed time: ", request.getElapsedTime());

            // Fulfill the request with the received data and wake up sleepers
            request.future.receiveWake(packet);
        }
        else
        {
            // TODO: pubsub support doe?
            // TODO: What to do with reeived? no match just discard
            writeln("Discarding received packet '"~packet.toString()~"' as it matches no request");
        }
    }
}