module doap.exceptions;

public class CoapException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}