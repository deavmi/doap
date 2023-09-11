module doap.packet;

import doap.codes : Code;

/** 
 * Represents a CoAP packet
 */
public class CoapPacket
{
    private ubyte ver, type;
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

        return encoded;
    }

}