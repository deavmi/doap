![](branding/logo.png)

doap
====

[![D](https://github.com/deavmi/doap/actions/workflows/d.yml/badge.svg?branch=master)](https://github.com/deavmi/doap/actions/workflows/d.yml) [![Coverage Status](https://coveralls.io/repos/github/deavmi/doap/badge.svg?branch=master)](https://coveralls.io/github/deavmi/doap?branch=master)

**doap** is a CoAP library for the D programming language.

## Usage

Documentation is available [here](https://doap.dpldocs.info/).

### Making a request

```d
CoapClient client = new CoapClient("coap.me", 5683);
    
CoapRequestFuture future = client.newRequestBuilder()
                        .payload(cast(ubyte[])"Hello this is Tristan!")
                        .token([69])
                        .post();


writeln("Future start");
CoapPacket response  = future.get();
writeln("Future done");
writeln("Got response: ", response);

client.close();
```

## License

This project is licensed under the [LGPL v3.0](LICENSE).
