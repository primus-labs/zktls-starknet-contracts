import { Account, RpcProvider, Contract, constants, RPC, num, ec } from 'starknet';
import { exit } from 'process';
import { assert } from 'console';


// Modify the following fields
const ACCOUNT_PRIVATE_KEY = "0x0000000000000000000000000000000071d7bb07b9a64f6f78ac4c816aff4da9";
const ACCOUNT_ADDRESS = "0x64b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691";
// RPC node ref: https://starknetjs.com/docs/guides/connect_network
const RPC_NODE_URL = "http://127.0.0.1:5050/rpc";
// PrimusZKTL Contract Address
const CONTRACT_ADDRESS = "0x068f842547c076a2ab01e66e6a63e1f24ec7b5a0da942fc0812789038921ee8b";
//


const publicKey = ec.starkCurve.getStarkKey(ACCOUNT_PRIVATE_KEY);
console.log('publicKey=', publicKey);

const provider = new RpcProvider({ nodeUrl: RPC_NODE_URL });
const resp = await provider.getSpecVersion();
console.log('RPC version=', resp);

const account = new Account(
  provider,
  ACCOUNT_ADDRESS,
  ACCOUNT_PRIVATE_KEY,
  undefined,
  constants.TRANSACTION_VERSION.V3
);
console.log('account=', account);


// Contract class of compiled contract
const compiledContract = await provider.getClassAt(CONTRACT_ADDRESS);
const myContract = new Contract(compiledContract.abi, CONTRACT_ADDRESS, provider);


// Connect account with the contract
myContract.connect(account);


//
// Helper functions
const hexStringToByteArray = (hex) => {
  if (hex.startsWith('0x')) { hex = hex.slice(2); }
  if (hex.length % 2 !== 0) { hex = '0' + hex; }
  return Array.from({ length: hex.length / 2 }, (_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16));
}

const signAndExecuteTransaction = async (clldata) => {
  console.log(`clldata: ${JSON.stringify(clldata)}`);

  const maxQtyGasAuthorized = 1800000n; // max quantity of gas authorized
  const maxPriceAuthorizeForOneGas = 12n * 10n ** 9n; // max FRI authorized to pay 1 gas (1 FRI=10**-18 STRK)
  console.log('max authorized cost =', maxQtyGasAuthorized * maxPriceAuthorizeForOneGas, 'FRI');
  const { transaction_hash: txH } = await account.execute(clldata, {
    version: 3,
    maxFee: 10 ** 15,
    feeDataAvailabilityMode: RPC.EDataAvailabilityMode.L1,
    tip: 10 ** 13,
    paymasterData: [],
    resourceBounds: {
      l1_gas: {
        max_amount: num.toHex(maxQtyGasAuthorized),
        max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
      },
      l1_data_gas: {
        max_amount: num.toHex(maxQtyGasAuthorized),
        max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
      },
      l2_gas: {
        max_amount: num.toHex(50_000_000),
        max_price_per_unit: num.toHex(12e9),
      },
    },
  });
  const txR = await provider.waitForTransaction(txH);
  console.log('txR', txR);
  if (txR.isSuccess()) {
    console.log('SUCCESSED. Paid fee =', txR.actual_fee);
  }
};


//
// Interact
const test_encode_request = async () => {
  const request = { url: "url", header: "header", method: "method", body: "body" };
  const hash = await myContract.encodeRequest(request);
  console.log('encodeRequest hash', hash.toString(16));
  assert(hash == 0x6516ff20b12fab566bffa0007a21e4790d74345696806422615c31a2bbe04698n, "encodeRequest failed")
};

await test_encode_request();
// exit(0);


const set_attestor = async () => {
  const attestor1 = "0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7";
  const attestor = { attestorAddr: attestor1, url: "https://@0xF1.com/" };

  const calldata = myContract.populate('setAttestor', [attestor]);
  await signAndExecuteTransaction(calldata);
};

await set_attestor();
// exit(0);


const test_verify_attestation = async () => {
  const request = { url: "url", header: "header", method: "method", body: "body" };
  const response = { keyName: "keyName", parseType: "parseType", parsePath: "parsePath" };
  const responses = [response, response];
  const signature = hexStringToByteArray("0x0f3e8bb94995df52b1a454f9a96e3a62f9c0446c8fa2ead68007f6dc11b7dadf3cd24e5ed0ce4573e6097c601d6a8636d234964d974f1a91a8f03ab6040114931b");
  const recipient = "0xa302153842e73FCEeEcFdA568de2A4A97C000BFb";
  const attestation = {
    recipient: recipient,
    request: request,
    reponseResolve: responses,
    data: "data",
    attConditions: "attConditions",
    timestamp: 0x1234567890abcd,
    additionParams: "additionParams",
    attestors: [],
    signatures: [signature],
  };

  const calldata = myContract.populate('verifyAttestation', [attestation]);
  await signAndExecuteTransaction(calldata);
};

await test_verify_attestation();
exit(0);
