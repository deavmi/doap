module doap.packet;

import doap.types : MessageType;
import doap.codes : Code;

/** 
 * Represents a CoAP packet
 */
public class CoapPacket
{
    private ubyte ver;
    private MessageType type;
    private ubyte tokenLen;
    private Code code;
    private ushort mid;
    private ubyte[] token;
    private uint options;
    private ubyte[] payload;

    this()
    {
        // Set the version (Default is 1)
        ver = 1;
    }

    public ubyte[] getBytes()
    {
        ubyte[] encoded;

        // Calculate the first byte (ver | type | tkl)
        ubyte firstByte = cast(ubyte)(ver << 6);
        firstByte = firstByte | cast(ubyte)(type << 4);
        firstByte = firstByte | tokenLen;
        encoded ~= firstByte;

        // Set the request/response code
        encoded ~= code;

        // Set the message ID
        

        return encoded;
    }

    public void setType(MessageType type)
    {
        this.type = type;
    }

    // public ubyte getVersion()
    // {

    // }

}

version(unittest)
{
    import std.stdio;
}

/**
 * Encoding tests
 *
 * These set high level parameters and then
 * we call `getBytes()` and analyse the components
 * of the encoded wire format by hand to ensure
 * they are set in place correctly
 */
unittest
{
    CoapPacket packet = new CoapPacket();
    packet.setType(MessageType.RESET);

    ubyte[] encoded = packet.getBytes();

    ubyte firstByte = encoded[0];

    // Ensure the version is set to 1
    ubyte versionField = cast(ubyte)(firstByte & 192) >> 6;
    assert(versionField == 1);

    // Ensure the type is 3/RESET
    ubyte typeField = cast(ubyte)(firstByte & 48) >> 4;
    assert(typeField == MessageType.RESET);

}