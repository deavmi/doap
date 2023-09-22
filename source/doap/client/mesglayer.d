module doap.client.mesglayer;

import doap.client.client : CoapClient;
import std.socket : Address;

public abstract class CoapMessagingLayerFR
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
}