module doap.protocol.types;

public enum MessageType : ubyte
{
    // Request
    CONFIRMABLE = 0,
    NON_CONFIRMABLE = 1,

    // Response
    ACKNOWLEDGEMENT = 2,
    RESET = 3
}