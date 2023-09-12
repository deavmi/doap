module doap.packet;

import doap.types : MessageType;
import doap.codes : Code;
import doap.exceptions : CoapException;

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

        // Set the message ID (encoded as big endian)
        version(LittleEndian)
        {
            ubyte* basePtr = cast(ubyte*)&mid;
            ubyte lowByte = *basePtr;
            ubyte hiByte = *(basePtr+1);

            encoded ~= [hiByte, lowByte];

        }
        else version(BigEndian)
        {
            ubyte* basePtr = cast(ubyte*)&mid;
            ubyte lowByte = *(basePtr+1);
            ubyte hiByte = *(basePtr);
            encoded ~= [hiByte, lowByte];
        }

        // Set the token (if any)
        if(tokenLen)
        {
            encoded ~= token;
        }
        
        return encoded;
    }

    public void setType(MessageType type)
    {
        this.type = type;
    }

    public void setToken(ubyte[] token)
    {
        if(setTokenLength(token.length))
        {
            this.token = token;
        }
        else
        {
            throw new CoapException("Token length above 15 bytes not allowed");
        }
    }

    private bool setTokenLength(ulong tkl)
    {
        if(tkl > 15)
        {
            return false;
        }
        else
        {
            this.tokenLen = cast(ubyte)tkl;
            return true;    
        }
    }

    public void setCode(Code code)
    {
        this.code = code;
    }

    public void setMessageId(ushort mid)
    {
        this.mid = mid;
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

    ubyte[] token = [0, 69];
    packet.setToken(token);

    packet.setCode(Code.PONG);

    packet.setMessageId(257);





    ubyte[] encoded = packet.getBytes();

    ubyte firstByte = encoded[0];

    // Ensure the version is set to 1
    ubyte versionField = cast(ubyte)(firstByte & 192) >> 6;
    assert(versionField == 1);

    // Ensure the type is 3/RESET
    ubyte typeField = cast(ubyte)(firstByte & 48) >> 4;
    assert(typeField == MessageType.RESET);

    // Ensure the token length is 2
    ubyte tklField = firstByte & 15;
    assert(tklField == token.length);

    ubyte secondByte = encoded[1];

    // Ensure the code is set to PONG
    // Class is 7
    // Code is 3
    ubyte codeClass = cast(ubyte)(secondByte & 224)  >> 5;
    assert(codeClass == 7);
    ubyte code = (secondByte & (~224));
    assert(code == 3);
    writeln(codeClass);
    writeln(code);
    assert(secondByte == Code.PONG);

    // Ensure the message ID is 257
    ubyte thirdByte = encoded[2], fourthByte = encoded[3];
    assert(thirdByte == 1);
    assert(fourthByte == 1);

    // Ensure the token is [0, 69]
    ubyte fifthByte = encoded[4], sixthByte = encoded[5];
    assert(fifthByte == 0);
    assert(sixthByte == 69);

}
