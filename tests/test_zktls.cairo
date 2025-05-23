use core::to_byte_array::FormatAsByteArray;
use primus_zktls::IPrimusZKTLS::{
    AttNetworkRequest, AttNetworkResponseResolve, Attestation, Attestor, IPrimusZKTLSDispatcher,
    IPrimusZKTLSDispatcherTrait,
};
use primus_zktls::utils;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, EthAddress};


fn owner() -> ContractAddress {
    0xC0FFEE.try_into().unwrap()
}

fn deployPrimusZKTLS() -> ContractAddress {
    let owner = owner();
    let defaultAddr: EthAddress = 0xAfC79DFa002408C479dDa0384831E73616B721C4_felt252
        .try_into()
        .unwrap();

    let mut calldata = array![];
    owner.serialize(ref calldata);
    defaultAddr.serialize(ref calldata);

    let contract = declare("PrimusZKTLS").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn create_simple_request() -> AttNetworkRequest {
    let request = AttNetworkRequest {
        url: "url", header: "header", method: "method", body: "body",
    };
    request
}


fn create_simple_responses() -> Array<AttNetworkResponseResolve> {
    let response = AttNetworkResponseResolve {
        keyName: "keyName", parseType: "parseType", parsePath: "parsePath",
    };
    array![response.clone(), response]
}

fn create_simple_attestation(
    request: AttNetworkRequest,
    responses: Array<AttNetworkResponseResolve>,
    signatures: Array<Array<u8>>,
) -> Attestation {
    let attestation = Attestation {
        recipient: 0xa302153842e73FCEeEcFdA568de2A4A97C000BFb_felt252.try_into().unwrap(),
        request: request,
        reponseResolve: responses,
        data: "data",
        attConditions: "attConditions",
        timestamp: 0x1234567890abcd,
        additionParams: "additionParams",
        attestors: array![],
        signatures: signatures,
    };

    attestation
}

#[test]
fn test_zktls_encode_request() {
    let contract_address = deployPrimusZKTLS();
    println!("contract_address: {:?}", contract_address);
    let dispatcher = IPrimusZKTLSDispatcher { contract_address };

    let request = create_simple_request();
    let hash = dispatcher.encodeRequest(request);
    println!("encodeRequest hash: {:?}", hash.format_as_byte_array(16));
    assert!(
        hash == 0x6516ff20b12fab566bffa0007a21e4790d74345696806422615c31a2bbe04698,
        "encode request failed",
    );
}

#[test]
fn test_zktls_encode_response() {
    let contract_address = deployPrimusZKTLS();
    println!("contract_address: {:?}", contract_address);
    let dispatcher = IPrimusZKTLSDispatcher { contract_address };

    let responses = create_simple_responses();
    let hash = dispatcher.encodeResponse(responses);
    println!("encodeResponse hash: {:?}", hash.format_as_byte_array(16));
    assert!(
        hash == 0x7bf1beb260e2560e9c8dc1c7d859b5fa15fab01041779bdd85ed5096125a9441,
        "encode responses failed",
    );
}

#[test]
fn test_zktls_encode_attestation() {
    let contract_address = deployPrimusZKTLS();
    println!("contract_address: {:?}", contract_address);
    let dispatcher = IPrimusZKTLSDispatcher { contract_address };

    let request = create_simple_request();
    let responses = create_simple_responses();
    let attestation = create_simple_attestation(request, responses, array![array![0]]);
    let hash = dispatcher.encodeAttestation(attestation);
    println!("encodeAttestation hash: {:?}", hash.format_as_byte_array(16));
    assert!(
        hash == 0x0f09a2e1f589ab0f110826916f6c1d60b87c9ed9b30905fedc904ef0ab73447d,
        "encode attestation failed",
    );
}

#[test]
fn test_zktls() {
    // createPrimusZktls
    let contract_address = deployPrimusZKTLS();
    println!("contract_address: {:?}", contract_address);
    let dispatcher = IPrimusZKTLSDispatcher { contract_address };

    // set the caller address
    start_cheat_caller_address(contract_address, owner());

    // setAttestor
    {
        let mut spy = spy_events();
        {
            let attestor1 = 0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7_felt252.try_into().unwrap();
            let attestor = Attestor { attestorAddr: attestor1, url: "https://@0xF1.com/" };
            dispatcher.setAttestor(attestor);

            assert(spy.get_events().events.len() == 1, 'There should be one event');
        }

        {
            let attestor2 = 0x570B4A56255f7509266783a81C3438fd5D7067B6_felt252.try_into().unwrap();
            let attestor = Attestor { attestorAddr: attestor2, url: "https://@0xF2.com/" };
            dispatcher.setAttestor(attestor);

            assert(spy.get_events().events.len() == 2, 'There should be one event');
        }
    }

    // removeAttestor
    {
        let mut spy = spy_events();
        let attestor2 = 0x570B4A56255f7509266783a81C3438fd5D7067B6_felt252.try_into().unwrap();
        dispatcher.removeAttestor(attestor2);
        assert(spy.get_events().events.len() == 1, 'There should be one event');
    }

    // verifyAttestation
    {
        let signature =
            "0f3e8bb94995df52b1a454f9a96e3a62f9c0446c8fa2ead68007f6dc11b7dadf3cd24e5ed0ce4573e6097c601d6a8636d234964d974f1a91a8f03ab6040114931b";
        let signature = utils::hex_to_bytes2(signature);

        let request = create_simple_request();
        let responses = create_simple_responses();
        let attestation = create_simple_attestation(request, responses, array![signature]);

        dispatcher.verifyAttestation(attestation);
    }

    stop_cheat_caller_address(contract_address);
}
