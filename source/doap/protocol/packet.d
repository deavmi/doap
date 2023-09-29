module doap.protocol.packet;

import doap.protocol.types : MessageType;
import doap.protocol.codes : Code;
import doap.exceptions : CoapException;
import std.conv : to;
import doap.utils : order, Order, toBytes;

/** 
 * Payload marker
 */
private ubyte PAYLOAD_MARKER = cast(ubyte)-1;

/** 
 * A header option
 */
public struct CoapOption
{
    /** 
     * Option ID
     */
    public ushort id;

    /** 
     * Option value
     */
    public ubyte[] value;
}


// TODO: remove this
import std.stdio : writeln;


private enum OptionLenType
{
    ZERO_TO_TWELVE,
    _8BIT_EXTENDED,
    _12_BIT_EXTENDED,
    UPPER_PAYLOAD_MARKER
}

private enum OptionDeltaType
{
    ZERO_TO_TWELVE,
    _8BIT_EXTENDED,
    _12_BIT_EXTENDED,
    UPPER_PAYLOAD_MARKER
}


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
    private CoapOption[] options;
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

        // FIXME: Add options encoding
        ushort curDelta = 0;
        foreach(CoapOption option; orderOptions())
        {
            encoded ~= encodeOption(option, curDelta);
        }

        // Set the payload marker
        encoded ~= PAYLOAD_MARKER;

        // Set the payload
        encoded ~= payload;
        
        return encoded;
    }

    // TODO: Make public in the future
    private static ubyte[] encodeOption(CoapOption option, ref ushort delta)
    {
        // Finally constructed option encoded
        ubyte[] encoded;

        // Update delta to option.id-delta
        delta = cast(ushort)(option.id-delta);

        // Determine the option id type
        OptionDeltaType optType = determineOptionType(option.id);

        // Determine the length type
        size_t len = option.value.length;
        OptionLenType lenType = determineLenType(len);

        // Construct the header (option delta)
        if(optType == OptionDeltaType.ZERO_TO_TWELVE)
        {
            // Encode the option delta directly
            ubyte optHdr = cast(ubyte)(delta<<4);

            // Add the `(Option delta | Option length)`
            encoded ~= optHdr;
        }
        else if(optType == OptionDeltaType._8BIT_EXTENDED)
        {
            // Encode the value 13
            ubyte optHdr = cast(ubyte)(13<<4);

            // Add the `(Option delta | Option length)`
            encoded ~= optHdr;

            // Now tack on the delta-13
            encoded ~= cast(ubyte)(delta-13);
        }
        else if(optType == OptionDeltaType._12_BIT_EXTENDED)
        {
            // Encode the value 14
            ubyte optHdr = cast(ubyte)(14<<4);

            // Add the `(Option delta | Option length)`
            encoded ~= optHdr;

            // Now tack on the delta-269
            encoded ~= toBytes(order(cast(ushort)(delta-269), Order.BE));
        }
        else
        {
            throw new CoapException("Cannot encode an option with invalid id of '"~to!(string)(option.id)~"'");
        }
        
        // Construct the header (option length)
        if(lenType == OptionLenType.ZERO_TO_TWELVE)
        {
            // Encode the length directly
            ubyte lenHdr = cast(ubyte)(len&15);  // TODO: Remove useless and

            // Add the `(Option delta | Option length)`
            encoded[0] |= lenHdr;   
        }
        else if(lenType == OptionLenType._8BIT_EXTENDED)
        {
            // Encode the value 13
            ubyte lenHdr = cast(ubyte)(13&15); // TODO: Remove useless and

            // Add the `(Option delta | Option length)`
            encoded[0] |= lenHdr;

            // Now tack on the length-13
            encoded ~= [cast(ubyte)(len-13)];
        }
        else if(lenType == OptionLenType._12_BIT_EXTENDED)
        {
             // Encode the value 14
            ubyte lenHdr = cast(ubyte)(14&15);  // TODO: Remove useless and

            // Add the `(Option delta | Option length)`
            encoded[0] |= lenHdr;

            // Now tack on the length-269
            encoded ~= toBytes(order(cast(ushort)(len-269), Order.BE));
        }
        else
        {
            throw new CoapException("Cannot encode an option with a length of '"~to!(string)(option.value.length)~"'");
        }
        
        // Now tack on the option value
        encoded ~= option.value;
        
        return encoded;
    }

    private CoapOption[] orderOptions()
    {
        // TODO: Implement ordering here
        return this.options;
    }

    public void addOption(CoapOption option)
    {
        this.options ~= [option];
    }

    /** 
     * Given a payload size this determines
     * the required type of option length
     * encoding to be used.
     *
     * If the size is unsupported then
     * `OptionLenType.UPPER_PAYLOAD_MARKER`
     * is returned.
     *
     * Params:
     *   dataSize = the payload's size
     * Returns: the `OptionLenType`
     */
    private static OptionLenType determineLenType(size_t dataSize)
    {
        if(dataSize >= 0 && dataSize <= 12)
        {
            return OptionLenType.ZERO_TO_TWELVE;
        }
        else if(dataSize >= 13 && dataSize <= 268)
        {
            return OptionLenType._8BIT_EXTENDED;
        }
        else if(dataSize >= 269 && dataSize <= 65804)
        {
            return OptionLenType._12_BIT_EXTENDED;
        }
        else
        {
            return OptionLenType.UPPER_PAYLOAD_MARKER;
        }
    }

    /** 
     * Given an option ID this determines
     * the required type of option id
     * encoding to be used.
     *
     * If the size is unsupported then
     * `OptionLenType.UPPER_PAYLOAD_MARKER`
     * is returned.
     *
     * Params:
     *   id = the option id
     * Returns: the `OptionDeltaType`
     */
    private static OptionDeltaType determineOptionType(size_t id)
    {
        if(id >= 0 && id <= 12)
        {
            return OptionDeltaType.ZERO_TO_TWELVE;
        }
        else if(id >= 13 && id <= 268)
        {
            return OptionDeltaType._8BIT_EXTENDED;
        }
        else if(id >= 269 && id <= 65804)
        {
            return OptionDeltaType._12_BIT_EXTENDED;
        }
        else
        {
            return OptionDeltaType.UPPER_PAYLOAD_MARKER;
        }
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

    public void setOptions()
    {
        // FIXME: Implement me
    }

    public void setPayload(ubyte[] payload)
    {
        this.payload = payload;
    }

    public ubyte getVersion()
    {
        return this.ver;
    }

    public MessageType getType()
    {
        return this.type;
    }

    public ubyte getTokenLength()
    {
        return this.tokenLen;
    }

    public ubyte[] getToken()
    {
        return this.token;
    }

    public Code getCode()
    {
        return this.code;
    }

    public ushort getMessageId()
    {
        return this.mid;
    }

    public static CoapPacket fromBytes(ubyte[] data)
    {
        CoapPacket packet = new CoapPacket();

        if(data.length < 4)
        {
            throw new CoapException("CoAP message must be at least 4 bytes in size");
        }

        packet.ver = data[0]>>6;
        packet.type = cast(MessageType)( (data[0]>>4) & 3);
        packet.tokenLen = data[0]&15;

        packet.code = cast(Code)(data[1]);
        writeln("Decoded code: ", packet.code);


        ubyte* midBase = data[2..4].ptr;
        version(LittleEndian)
        {
            ubyte* pMidBase = cast(ubyte*)&packet.mid;
            *(pMidBase) = *(midBase+1);
            *(pMidBase+1) = *(midBase);
        }
        else version(BigEndian)
        {
            ubyte* pMidBase = cast(ubyte*)&packet.mid;
            *(pMidBase) = *(midBase);
            *(pMidBase+1) = *(midBase+1);
        }

        if(packet.tokenLen)
        {
            packet.token = data[4..4+packet.tokenLen];
        }

        // TODO: Do options decode here
        ubyte[] remainder = data[4+packet.tokenLen..$];
        version(unittest) writeln("Remainder: ", remainder);

        ulong idx = 4+packet.tokenLen;

        writeln();
        writeln();

        CoapOption[] createdOptions;
        if(remainder.length)
        {
            // import std.container.slist : SList;
            // SList!(CoapOption) createdOptions;

            // First "previous" delta is 0
            ushort delta = 0;

            ushort curOptionNumber;
            while(true)
            {
                writeln("Delta (ENTER): ", delta);
                writeln("Remainder [from-idx..$] (ENTER): ", data[idx..$]);

                scope(exit)
                {
                    writeln("Currently built options: ", createdOptions);
                    writeln();
                    writeln();
                }

                ubyte curValue = data[idx];

                // If entire current value is -1/~0
                // then we reached the payload marker
                if(curValue == PAYLOAD_MARKER)
                {
                    writeln("Found payload marker, stopping option parsing");
                    idx++;
                    break;

                }


                ubyte computed = (curValue&240) >> 4;
                writeln("Computed delta: ", computed);

                // 0 to 12 Option ID
                if(computed >= 0 && computed <= 12)
                {
                    writeln("Delta is 0 to 12");

                    // In such a case the delta we add on is this 4 bit eneity
                    delta+=computed;
                    writeln("Option id: ", delta);


                    // Get the type of option length
                    OptionLenType optLenType = getOptionLenType(curValue);
                    writeln("Option length type: ", optLenType);

                    // Simple case (12)
                    if(optLenType == OptionLenType.ZERO_TO_TWELVE)
                    {
                        // Compute the length
                        ubyte optLen = (curValue&15);
                        writeln("Option len: ", optLen);

                        // Update idx to jump over the (option delta | option length)
                        idx+=1;

                        // Grab the data from [idx, idx+length)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (8bit) (13)
                    else if(optLenType == OptionLenType._8BIT_EXTENDED)
                    {
                        // Next byte has the length
                        idx+=1;

                        // The total length is the extended value (which lacks 13 so we must add it)
                        writeln(data[idx..$]);
                        ubyte optLen8BitExt = data[idx];
                        ushort optLen = optLen8BitExt+13;
                        writeln("Option len: ", optLen);
                        
                        // Jump over 8bit opt len ext
                        idx+=1;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (16bit) (14)
                    else if(optLenType == OptionLenType._12_BIT_EXTENDED)
                    {
                        // TODO: THIS IS UNTESTED CODE!!!

                        // Jump to next byte of two bytes (which has length)
                        idx+=1;

                        // Option length compute (it lacks 269 so add it back)
                        ushort optLen = order(*cast(ushort*)&data[idx], Order.BE);
                        optLen+=269;
                        writeln("Option len: ", optLen);

                        // Jump over the two option length bytes
                        idx+=2;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                }
                // 13
                else if(computed == 13)
                {
                    writeln("3333 Option delta type: 13 - DEVELOPER ADD SUPPORT! 3333");

                    // TODO: This is UNTESTED code!!!!

                    // Skip over the 4bit tuple
                    idx+=1;

                    // Delta value is 1 byte (the value found is lacking 13 so add it back)
                    ubyte deltaAddition = data[idx];
                    deltaAddition+=13;

                    // Update delta
                    delta+=deltaAddition;

                    // Our option ID is then calculated from the current delta
                    ushort optionId = delta;

                    // Jump over the 1 byte option delta
                    idx+=1;

                    writeln("8 bit option-id delta: ", optionId);

                    // Get the type of option length
                    OptionLenType optLenType = getOptionLenType(curValue);
                    writeln("Option length type: ", optLenType);

                    // Simple case (12)
                    if(optLenType == OptionLenType.ZERO_TO_TWELVE)
                    {
                        // Compute the length
                        ubyte optLen = (curValue&15);
                        writeln("Option len: ", optLen);

                        // Grab the data from [idx, idx+length)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (8bit) (13)
                    else if(optLenType == OptionLenType._8BIT_EXTENDED)
                    {
                        // The total length is the extended value (which lacks 13 so we must add it)
                        writeln(data[idx..$]);
                        ubyte optLen8BitExt = data[idx];
                        ushort optLen = optLen8BitExt+13;
                        writeln("Option len: ", optLen);
                        
                        // Jump over 8bit opt len ext
                        idx+=1;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (16bit) (14)
                    else if(optLenType == OptionLenType._12_BIT_EXTENDED)
                    {
                        // Option length compute (it lacks 269 so add it back)
                        ushort optLen = order(*cast(ushort*)&data[idx], Order.BE);
                        optLen+=269;
                        writeln("Option len: ", optLen);

                        // Jump over the two option length bytes
                        idx+=2;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                }
                // 14
                else if(computed == 14)
                {
                    writeln("Option delta type: 14 - DEVELOPER ADD SUPPORT!");

                    // Skip over 4bit tuple
                    idx+=1;

                    // Delta value is 2 bytes (BE)
                    ubyte[] optionIdBytes = data[idx..idx+2];
                    ushort unProcessedValue = *(cast(ushort*)optionIdBytes.ptr);

                    // The value found is then lacking 269 (so add it back)
                    ushort deltaAddition = order(unProcessedValue, Order.BE);
                    deltaAddition+=269;

                    // Update delta
                    delta+=deltaAddition;

                    // Our option ID is then calculated from the current delta
                    ushort optionId = delta;

                    // Jump over [Option delta extended (16bit)] here
                    idx+=2;

                    writeln("16 bit option-id delta: ", optionId);

                    // Get the option length type
                    OptionLenType optLenType = getOptionLenType(curValue);
                    writeln("Option len type: ", optLenType);

                    // 0 to 12 length type
                    if(optLenType == OptionLenType.ZERO_TO_TWELVE)
                    {
                        // Option length
                        ubyte optLen = (curValue&15);
                        writeln("Option len: ", optLen);

                        // Read the option now
                        ubyte[] optionValue = data[idx..idx+optLen];

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = optionId;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (8bit) (13)
                    else if(optLenType == OptionLenType._8BIT_EXTENDED)
                    {
                        // TODO: THIS IS UNTESTED CODE!!!!

                        // The total length is the extended value (which lacks 13 so we must add it)
                        writeln(data[idx..$]);
                        ubyte optLen8BitExt = data[idx];
                        ushort optLen = optLen8BitExt+13;
                        writeln("Option len: ", optLen);
                        
                        // Jump over 8bit opt len ext
                        idx+=1;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    // Option length extended (16bit) (14)
                    else if(optLenType == OptionLenType._12_BIT_EXTENDED)
                    {
                        // TODO: THIS IS UNTESTED CODE!!!!

                        // Option length compute (it lacks 269 so add it back)
                        ushort optLen = order(*cast(ushort*)&data[idx], Order.BE);
                        optLen+=269;
                        writeln("Option len: ", optLen);

                        // Jump over the two option length bytes
                        idx+=2;

                        // Grab the data from [idx, idx+optLen)
                        ubyte[] optionValue = data[idx..idx+optLen];
                        writeln("Option value: ", optionValue);
                        writeln("Option value: ", cast(string)optionValue);

                        // Jump over the option value
                        idx+=optLen;

                        // Create the option and add it to the list of options
                        CoapOption option;
                        option.value = optionValue;
                        option.id = delta;
                        writeln("Built option: ", option);
                        createdOptions ~= option;
                    }
                    else
                    {
                        writeln("OptionDelta14 Mode: We don't yet support other option lengths in this mode");
                        assert(false);
                    }



                    
                    
                    // Move onto the first byte of the next two (16 bit BE option-length extended)

                    writeln("Support not yet finished for delta type 14");

                    // break;
                }
                // 15
                else if(computed == 15)
                {
                    writeln("FIVEFIVEFIVE Option delta type: 15 - DEVELOPER ADD SUPPORT! FIVEFIVEFIVE");
                    assert(false);
                }
                else
                {
                    assert(false);
                }

                // break;
            }
        }

        packet.options = createdOptions;



        return packet;
    }

    /** 
     * Extracts the option length encoding
     * type from the header
     *
     * Params:
     *   hdr = the header
     * Returns: the `OptionLenType`
     */
    private static OptionLenType getOptionLenType(ubyte hdr)
    {
        ubyte type = (hdr&15);
        if(type >= 0 && type <= 12)
        {
            return OptionLenType.ZERO_TO_TWELVE;
        }
        else if(type == 13)
        {
            return OptionLenType._8BIT_EXTENDED;
        }
        else if(type == 14)
        {
            return OptionLenType._12_BIT_EXTENDED;
        }
        else
        {
            return OptionLenType.UPPER_PAYLOAD_MARKER;
        }
    }

    

    public override string toString()
    {
        return "CoapPacket [ver: "~to!(string)(ver)~
                            ", type: "~to!(string)(type)~
                            ", tkl: "~to!(string)(tokenLen)~
                            ", code: "~to!(string)(code)~
                            ", mid: "~to!(string)(mid)~
                            ", token: "~to!(string)(token)~
                            ", options: "~to!(string)(options)~
                            "]";
    }

}

version(unittest)
{
    import std.stdio;
}

/**
 * Tests `CoapPacket`'s `determineLenType(size_t)'
 */
unittest
{
    assert(CoapPacket.determineLenType(12) == OptionLenType.ZERO_TO_TWELVE);
    assert(CoapPacket.determineLenType(268) == OptionLenType._8BIT_EXTENDED);
    assert(CoapPacket.determineLenType(65804) == OptionLenType._12_BIT_EXTENDED);
    assert(CoapPacket.determineLenType(65804+1) == OptionLenType.UPPER_PAYLOAD_MARKER);
}

/**
 * Tests `CoapPacket`'s `determineOptionType(size_t)'
 */
unittest
{
    assert(CoapPacket.determineOptionType(12) == OptionDeltaType.ZERO_TO_TWELVE);
    assert(CoapPacket.determineOptionType(268) == OptionDeltaType._8BIT_EXTENDED);
    assert(CoapPacket.determineOptionType(65804) == OptionDeltaType._12_BIT_EXTENDED);
    assert(CoapPacket.determineOptionType(65804+1) == OptionDeltaType.UPPER_PAYLOAD_MARKER);
}

unittest
{
    writeln("\n\n");

    CoapOption[] expectedOptions = [
        CoapOption(3, [49, 48, 48, 46, 54, 52, 46, 48, 46, 49, 50, 58, 53, 54, 56, 51]),
        CoapOption(12, [39, 17]),
        CoapOption(65001, [1]),
        CoapOption(65003, [16]),
        CoapOption(65005, [1])
    ];

    CoapPacket pack = new CoapPacket();
    foreach(CoapOption option; expectedOptions)
    {
        pack.addOption(option);
    }
    
    ubyte[] encodedPacket = pack.getBytes();

    // Now try decode the packet to we can see if it decodes
    // ... the options correctly
    CoapPacket actualPacket = CoapPacket.fromBytes(encodedPacket);


    writeln("\n\n");
}

/**
 * Tests the encoding of the following
 * combination for options encoding:
 *
 * 1. 0-12 Option delta
 * 2. 0-12 Option length
 */
unittest
{
    writeln("\n\n");

    // This option decoded correctly from a real-world example
    // ... so I dog food the expected output
    // ubyte[] expectedEncode = [146, 39, 17];

    // ushort optionId_expected = 12;
    // ubyte[] optionValue_expected = [39, 17];
    // CoapOption option = CoapOption(optionId_expected, optionValue_expected);



    // ubyte[] encoded = CoapPacket.encodeOption(option);
    // writeln("Encoded option: ", encoded);

    // assert(encoded == expectedEncode);

    writeln("\n\n");
}

unittest
{
    writeln("\n\n");

    // This option decoded correctly from a real-world example
    // ... so I dog food the expected output


    // ushort optionId_expected = 3;
    // ubyte[] optionValue_expected = cast(ubyte[])"100.64.0.12:5683";
    // CoapOption option = CoapOption(optionId_expected, optionValue_expected);


    // ubyte[] encoded = CoapPacket.encodeOption(option);
    // writeln("Encoded option: ", encoded);

    writeln("\n\n");
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

    // FIXME: Set options

    ubyte[] payload = cast(ubyte[])[-1, -2];
    writeln(payload.length);
    packet.setPayload(payload);



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

    // FIXME: Ensure options

    // Ensure the payload marker is here
    ubyte seventhByte = encoded[6];
    assert(seventhByte == PAYLOAD_MARKER);

    // Ensure the payload is [255, 254]
    // FIXME: Offset because of options later
    ubyte eighthByte = encoded[7], ninthByte = encoded[8];
    assert(eighthByte == 255);
    assert(ninthByte == 254);

}

/**
 * Decoding tests
 *
 * These tests take a byte array of an encoded
 * CoAP packet and then decodes it into a new
 * `CoapPacket` object
 */
unittest
{
    // Version: 1 | Type: RESET (3) : TLK: 0
    // Code: 2 (POST) | MID: 257
    ubyte[] packetData = [112, 2, 1, 1];

    CoapPacket packet = CoapPacket.fromBytes(packetData);

    assert(packet.getVersion() == 1);
    assert(packet.getType() == MessageType.RESET);
    assert(packet.getTokenLength() == 0);
    assert(packet.getCode() == Code.POST);
    // TODO: Add message ID check + token check
    assert(packet.getMessageId() == 257);
}

unittest
{
    writeln("Begin big coap test (lekker real life)\n\n");

    ubyte[] testingIn = [
                         0x41, 0x02, 0xcd, 0x47, 0x45, 0x3d,
                         0x03, 0x31, 0x30, 0x30, 0x2e, 0x36, 0x34, 0x2e,
                         0x30, 0x2e, 0x31, 0x32, 0x3a, 0x35,
                         0x36, 0x38, 0x33, 0x92, 0x27, 0x11, 0xe1, 0xfc,
                         0xd0, 0x01, 0x21, 0x10, 0x21, 0x01,
                         0xff, 0xc0, 0x01, 0xc1, 0x00, 0x0f, 0x00, 0x00,
                         0x28, 0x00, 0x00, 0xff, 0x02, 0x00
                        ];


    CoapPacket packet = CoapPacket.fromBytes(testingIn);
    writeln(packet);
}


// unittest
// {
//     writeln("Big another coap test (ALSO REAL LIFE FR ONGOD)\n\n");

//     ubyte[] testingIn = [
//                             0x61, 0x41, 0xa4, 0xdc, 0x45, 0xc2, 0x27, 0x11, 0xb1, 0x0e, 0xe1,
//                             0xfc, 0xc5, 0x01, 0x21, 0x10, 0x21, 0x01, 0xff, 0xc4, 0x01, 0xc1,
//                             0x00, 0x01, 0x46, 0x02, 0x04, 0x12, 0x00, 0x0f, 0x11, 0x03, 0x09,
//                             0x06, 0x00, 0x00, 0x28, 0x00, 0x00, 0xff, 0x02, 0x02, 0x01, 0x0b,
//                             0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x03, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x04, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x05, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x06, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x07, 0x16, 0x00, 0x00, 0x02, 0x03, 0x0f, 0x08, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x09, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x0a, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x0b, 0x16, 0x01, 0x00, 0x01, 0x06, 0x02, 0x02, 0x0f, 0x01, 0x16, 0x00, 0x02, 0x02, 0x0f, 0x02, 0x16, 0x00, 0x02, 0x02, 0x0f, 0x03, 0x16, 0x00, 0x02, 0x02, 0x0f, 0x04, 0x16, 0x00, 0x02, 0x02, 0x0f, 0x05, 0x16, 0x00, 0x02, 0x02, 0x0f, 0x06, 0x16, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x01, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x02, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x03, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x01, 0x00, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x00, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x36, 0x01, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x01, 0x01, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x01, 0x02, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x05, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x02, 0x00, 0x80, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x02, 0x00, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x02, 0x02, 0x80, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x03, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x0d, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x0e, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x0f, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x13, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x00, 0x00, 0x04, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x14, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x04, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x60, 0x3a, 0x10, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x01, 0x01, 0x86, 0x00, 0x1e, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x03, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x00, 0x02, 0x2b, 0x01, 0x01, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x00, 0x02, 0x2b, 0x01, 0x08, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06, 0x00, 0x02, 0x2b, 0x01, 0x09, 0xff, 0x02, 0x02, 0x01, 0x02, 0x02, 0x03, 0x0f, 0x01, 0x16, 0x01, 0x00, 0x02, 0x03, 0x0f, 0x02, 0x16, 0x01, 0x00, 0x01, 0x00, 0x02, 0x04, 0x12, 0x00, 0x01, 0x11, 0x00, 0x09, 0x06
//                         ];

//     CoapPacket packet = CoapPacket.fromBytes(testingIn);
//     writeln(packet);
// }

/**
 * Tests the minimum size required for a packet
 * (Negative case)
 */
unittest
{
    ubyte[] testingIn = [];

    try
    {
        CoapPacket packet = CoapPacket.fromBytes(testingIn);
        assert(false);
    }
    catch(CoapException e)
    {
        assert(true);
    }

    testingIn = [ 0x41, 0x02, 0xcd];

    try
    {
        CoapPacket packet = CoapPacket.fromBytes(testingIn);
        assert(false);
    }
    catch(CoapException e)
    {
        assert(true);
    }
}

/**
 * Tests the minimum size required for a packet
 * (Positive case)
 */
unittest
{
    // FIXME: Actually make a better example
    // ubyte[] testingIn = [0x41, 0x02, 0xcd, 0x47];

    // try
    // {
    //     CoapPacket packet = CoapPacket.fromBytes(testingIn);

    //     // TODO: Test
    //     assert(true);
    // }
    // catch(CoapException e)
    // {
    //     assert(false);
    // }
}