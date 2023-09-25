module doap.client.messaging.core;

import doap.client.client : CoapClient;
import std.socket : Address;
import doap.protocol.packet : CoapPacket;

public abstract class CoapMessagingLayer
{
    /** 
     * The client
     */
    private CoapClient client;

    /** 
     * Constructs a new messaging layer instance
     * associated with the provided client
     *
     * Params:
     *   client = the client
     */
    this(CoapClient client)
    {
        this.client = client;
    }

    /** 
     * Retrieves the client associated with
     * this messaging layer
     *
     * Returns: the `CoapClient`
     */
    public final CoapClient getClient()
    {
        return this.client;
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

    /**
     * Starts the messaging layer
     */
    public abstract void begin();

    /** 
     * Transmit the provided packet
     *
     * Params:
     *   packet = the `CoapPacket`
     * to transmit
     */
    public abstract void send(CoapPacket packet);

    /**
     * Stops the messaging layer
     */
    public abstract void close();
}