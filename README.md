
# zktls-starknet-contracts

## Overview

The origin contract ref https://github.com/primus-labs/zktls-contracts.

## Build

Ref [Environment Setup](https://docs.starknet.io/quick-start/environment-setup/) to setup the environment.

```sh
scarb build
```

## Test

```sh
scarb test
```

## Deploy (DevNet)

**start local Starknet Devnet**

```sh
starknet-devnet --seed=0
```

**import account(only once)**

```sh
sncast account import \
    --address=0x064b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691 \
    --type=oz \
    --url=http://127.0.0.1:5050 \
    --private-key=0x0000000000000000000000000000000071d7bb07b9a64f6f78ac4c816aff4da9 \
    --add-profile=devnet \
    --silent
```

**declare**

```sh
sncast --profile=devnet declare --contract-name=PrimusZKTLS
```
class_hash: 0x02cf465697738f0edb7e643ef4b691e1d122e945d66d091a9abd4124c5e64e7f


**deploy**
```sh
sncast --profile=devnet deploy \
    --class-hash=0x02cf465697738f0edb7e643ef4b691e1d122e945d66d091a9abd4124c5e64e7f \
    -c 0x64b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691 0xAfC79DFa002408C479dDa0384831E73616B721C4 \
    --salt=0
```
contract_address: 0x068f842547c076a2ab01e66e6a63e1f24ec7b5a0da942fc0812789038921ee8b



## Deploy (Sepolia)

https://docs.starknet.io/quick-start/sepolia/

