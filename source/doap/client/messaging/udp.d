module doap.client.messaging.udp;

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

import doap.client.messaging;

/**
 * UDP-based messaging layer
 *
 * Handles the actual sending and receiving
 * of datagrams and fulfilling of requests
 */
public class UDPMessaging : CoapMessagingLayer
{
    /** 
     * Reading-loop thread
     */
    private Thread readingThread;

    /** 
     * Running status
     */
    private bool running; // TODO: Check volatility

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
        super(client);
    }

    /** 
     * Starts the messaging layer by starting
     * the underlying transport and then the
     * reader loop
     */
    public override void begin() // Candidate for Interface
    {
        // TODO: Handle socket errors nicely?

        // Set status to running
        this.running = true;


        // TODO: IF connect fails then don't start messaging
        this.socket = new Socket(getEndpointAddress().addressFamily(), SocketType.DGRAM, ProtocolType.UDP);
        // this.socket.blocking(true);

        // TODO: Busy with this
        import std.socket : SocketOption, SocketOptionLevel;
        import core.time : dur;
        this.socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!("seconds")(5));
        // this.socket.blocking(false);


        this.socket.connect(getEndpointAddress());

        


        // Create the reading-loop thread and start it
        this.readingThread = new Thread(&loop);
        this.readingThread.start();
    }

    /** 
     * Transmit the provided packet
     *
     * Params:
     *   packet = the `CoapPacket`
     * to transmit
     */
    public override void send(CoapPacket packet) // Candidate for Interface
    {
        // Encode the packet and send the bytes
        ubyte[] encodedPacket = packet.getBytes();
        this.socket.send(encodedPacket);
    }

    /** 
     * Stops the messaging layer by
     * stopping the underlying network
     * transport and therefore the
     * reading loop
     *
     * Blocks till the reading loop
     * has terminated
     */
    public override void close() // Candidate for Interface
    {
        // Set status to not running
        this.running = false;

        // Shutdown the socket (stopping the messaging layer)
        this.socket.shutdown(SocketShutdown.BOTH);

        // Unbind (disallow incoming datagrams to source port (from device))
        this.socket.close();

        // Wait till the reading-loop thread exits
        this.readingThread.join();
    }

    /** 
     * Reading loop which reads datagrams
     * from the socket
     */
    private void loop()
    {
        // TODO: Ensure below condition works well
        while(this.running)
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


            /** 
             * With a UDP socket (so far I have seen) MSG_TRUNC
             * seems to screw up the `recv()` timeout behaviour,
             * therefore we should use the peek as our waiting
             * point, THEN PEEK+TRUNC and then finally normal
             * `recv()`
             */
            SocketFlags flags = cast(SocketFlags)(SocketFlags.PEEK);
            byte[] data;
            data.length = 1; // At least one else never does underlying recv()
            writeln("I wait recv()");
            ptrdiff_t dgramSize = this.socket.receive(data, flags);

            writeln("Peek'd recv: ", dgramSize < 0 ? "Timed out" : "Data available", "(", dgramSize, ")");

            // If we have timed out or socket shutdown or closed
            if(dgramSize < 0)
            {
                

                // TODO: Add up-call to client here
                writeln("Time out runner running now!");
                writeln("Status: ", this.socket.getErrorText());
                writeln("Status SOcket: ", this.socket.isAlive());

                import core.stdc.errno : errno;

                // If we timed out (then we'd still be alive)
                if(this.socket.isAlive())
                {
                    writeln("Timed out, doing up-call for retransmission checks");
                    this.getClient().onNoNewMessages();
                    writeln("Timed out, doing up-call for retransmission checks [done]");
                }

            }
            // If 0 then socket is closed
            else if(dgramSize == 0)
            {
                writeln("Socket closed");
                writeln("Status SOcket: ", this.socket.isAlive());
            }
            // There IS data available
            else
            {
                // Peek but use TRUNC to get the datagram size returned
                dgramSize = this.socket.receive(data, cast(SocketFlags)(SocketFlags.PEEK | MSG_TRUNC));
                writeln("MSG_TRUNC, Datagram size is: ", dgramSize);

                // FIXME: Check dgramSize, for case of error (calling on closed, or we get shutdown here)
                if(dgramSize <= 0)
                {
                    break;
                }

                // Now that we have the size, set the request-array's size to it and dequeue
                data.length = dgramSize;
                // FIXME: Check return value
                if(this.socket.receive(data) > 0)
                {
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
        CoapRequest request = getClient().yankRequest(packet.getToken());
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