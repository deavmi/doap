module doap.protocol.codes;

public enum Code : ubyte
{
    // Method: 0.XX
    EMPTY = 0,
    GET = 1,
    POST = 2,
    PUT = 3,
    DELETE = 4,
    FETCH = 5,
    PATCH = 6,
    iPATCH = 7,

    // Success: 2.XX
    CREATED = 1 | (1<<6),
    DELETED = 2 | (1<<6),
    VALID = 3 | (1<<6),
    CHANGED = 4 | (1<<6),
    CONTENT = 5 | (1<<6),
    CONTINUE = 31 | (1<<6),

    // Client Error: 4.XX
    BAD_REQUEST = 0 | (1<<7),
    UNAUTHORIZED = 1 | (1<<7),
    BAD_OPEN = 2 | (1<<7),
    FORBIDDEN = 3 | (1<<7),
    NOT_FOUND = 4 | (1<<7),
    METHOD_NOT_ALLOWED = 5 | (1<<7),
    NOT_ACCEPTABLE = 6 | (1<<7),
    REQUEST_ENTITY_INCOMPLETE = 8 | (1<<7),
    CONFLICT = 9 | (1<<7),
    PRECONDITION_FAILED = 12 | (1<<7),
    REQUEST_ENTITY_TOO_LARGE = 13 | (1<<7),
    UNSUPPORTED_CONTENT_FORMAT = 15 | (1<<7),

    // Server error: 5.XX
    INTERNAL_SERVER_ERROR = 0 | ((1<<5) | (1 << 7)),
    NOT_IMPLEMENTED = 1 | ((1<<5) | (1 << 7)),
    BAD_GATEWAY = 2 | ((1<<5) | (1 << 7)),
    SERVICE_UNAVAILABLE = 3 | ((1<<5) | (1 << 7)),
    GATEWAY_TIMEOUT = 4 | ((1<<5) | (1 << 7)),
    PROXYING_NOT_SUPPORTED = 5 | ((1<<5) | (1 << 7)),

    // Signaling Codes: 7.XX
    UNASSIGNED = 0 | ((1<<5) | (1 << 6) | (1 << 7)),
    CSM = 1 | ((1<<5) | (1 << 6) | (1 << 7)),
    PING = 2 | ((1<<5) | (1 << 6) | (1 << 7)),
    PONG = 3| ((1<<5) | (1 << 6) | (1 << 7)),
    RELEASE = 4 | ((1<<5) | (1 << 6) | (1 << 7)),
    ABORT = 5 | ((1<<5) | (1 << 6) | (1 << 7))
}