## MUST READ

* The base64 encoding algorithm is ENDIAN DEPENDENT. The default version only works
  with little endian. To compile the big endian version, run `make CEXTRAFLAGS="-DWORDS_BIGENDIAN"` instead.
* The base64 encoding algorithm requires ALIGNED strings, so it could be used only on x86(x64) and modern ARM architecture.
