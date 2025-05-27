use primus_zktls::IPrimusZKTLS::Attestation;
#[starknet::interface]
pub trait IAttestorTest<TState> {
    fn verifySignature(self: @TState, attestation: Attestation) -> bool;
}

#[starknet::contract]
mod AttestorTest {
    use primus_zktls::IPrimusZKTLS::{
        Attestation, IPrimusZKTLSDispatcher, IPrimusZKTLSDispatcherTrait,
    };
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _primusAddress: ContractAddress) {
        // Replace with the network you are deploying on
        self.address.write(_primusAddress);
    }

    #[abi(embed_v0)]
    impl IAttestorTest of super::IAttestorTest<ContractState> {
        fn verifySignature(self: @ContractState, attestation: Attestation) -> bool {
            IPrimusZKTLSDispatcher { contract_address: self.address.read() }
                .verifyAttestation(attestation);

            // Business logic checks, such as attestation content and timestamp checks
            // do your own business logic
            return true;
        }
    }
}
