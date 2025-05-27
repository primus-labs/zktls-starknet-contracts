# example of how to use PrimusZKTLS contract

## Deploy (DevNet)

**declare**

```sh
sncast --profile=devnet declare --contract-name=AttestorTest
```
class_hash: 0x05c53f5e28824549e8378e6fb028e76bae1594ac7a79c36dc4dd89d5ca074a18


**deploy**
```sh
sncast --profile=devnet deploy \
    --class-hash=0x05c53f5e28824549e8378e6fb028e76bae1594ac7a79c36dc4dd89d5ca074a18 \
    -c 0x068f842547c076a2ab01e66e6a63e1f24ec7b5a0da942fc0812789038921ee8b \
    --salt=0
```
contract_address: 0x0230dd8b8d335fa6bd20b8c442c72ad7a7e6d3cdfbc854f6891be63e3812b59b

