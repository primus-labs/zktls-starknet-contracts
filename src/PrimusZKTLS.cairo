/// @dev Implementation of the {IPrimusZKTLS} interface, providing
/// functionality to encode and verify attestations.
///
/// This contract also inherits {OwnableComponent} to enable ownership control,
/// NOTE: not support allowing for upgradeable contract management.
#[starknet::contract]
mod PrimusZKTLS {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use core::integer::u256;
    use core::keccak::compute_keccak_byte_array;
    use core::num::traits::Zero;
    use core::traits::Into;
    use openzeppelin::access::ownable::OwnableComponent;
    use primus_zktls::IPrimusZKTLS::{
        AttNetworkRequest, AttNetworkResponseResolve, Attestation, Attestor, IPrimusZKTLS,
    };
    use primus_zktls::utils;
    use starknet::secp256_trait::signature_from_vrs;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, EthAddress};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        // Mapping to store attestors for each address
        _attestorsMapping: Map<EthAddress, Attestor>,
        _attestors: Vec<Attestor>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AddAttestor: AddAttestor,
        DelAttestor: DelAttestor,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    /// Defines an event triggered when a new attestor is added
    /// @param _address The address of the attestor
    /// @param _attestor Detailed information about the attestor (could be a struct or contract
    /// type)
    #[derive(Drop, starknet::Event)]
    pub struct AddAttestor {
        pub _address: EthAddress,
        pub _attestor: Attestor,
    }

    /// Defines an event triggered when an existing attestor is removed
    /// @param _address The address of the attestor
    #[derive(Drop, starknet::Event)]
    pub struct DelAttestor {
        pub _address: EthAddress,
    }


    /// @dev initialize function to set the owner of the contract.
    /// This function is called during the contract deployment.
    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress, defaultAddr: EthAddress) {
        self.ownable.initializer(_owner);
        self.setupDefaultAttestor(defaultAddr);
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn setupDefaultAttestor(ref self: ContractState, defaultAddr: EthAddress) {
            assert(defaultAddr.is_non_zero(), 'Invalid address');

            let new_attestor = Attestor {
                attestorAddr: defaultAddr, url: "https://primuslabs.xyz/",
            };
            self._attestorsMapping.write(defaultAddr, new_attestor.clone());
            self._attestors.push(new_attestor);
        }
    }

    #[abi(embed_v0)]
    impl PrimusZKTLSImpl of IPrimusZKTLS<ContractState> {
        ///  @dev Allows the owner to set the attestor for a specific recipient.
        ///
        ///  Requirements:
        ///  - The caller must be the owner of the contract.
        ///
        ///
        ///  @param attestor The attestor to associate with the recipient.
        fn setAttestor(ref self: ContractState, attestor: Attestor) {
            self.ownable.assert_only_owner();
            assert(attestor.attestorAddr.is_non_zero(), 'Attestor address cannot be zero');

            if self._attestorsMapping.read(attestor.attestorAddr).attestorAddr.is_zero() {
                self._attestors.push(attestor.clone());
            }

            // Set the attestor for the recipient
            self._attestorsMapping.write(attestor.attestorAddr, attestor.clone());

            self.emit(AddAttestor { _address: attestor.attestorAddr, _attestor: attestor });
        }


        ///  @dev Removes the attestor for a specific recipient.
        ///
        ///  Requirements:
        ///  - The caller must be the owner of the contract.
        ///           attestorAddr
        ///  @param attestorAddr The address of the recipient whose attestor is to be removed.
        fn removeAttestor(ref self: ContractState, attestorAddr: EthAddress) {
            self.ownable.assert_only_owner();
            assert(attestorAddr.is_non_zero(), 'Recipient address cant be zero');
            assert(
                self._attestorsMapping.read(attestorAddr).attestorAddr.is_non_zero(),
                'No attestor found',
            );

            let attestor_zero = Attestor { attestorAddr: 0.try_into().unwrap(), url: "" };
            self._attestorsMapping.write(attestorAddr, attestor_zero);

            // update _attestors
            for i in 0..self._attestors.len() {
                if self._attestors.at(i).read().attestorAddr == attestorAddr {
                    let mut storage_ptr = self._attestors.at(i);
                    storage_ptr.write(self._attestors.at(self._attestors.len() - 1).read());
                    let _ = self._attestors.pop();
                    break;
                }
            }

            self.emit(DelAttestor { _address: attestorAddr });
        }


        /// @dev Encodes an attestation into a bytes32 hash.
        ///
        /// The encoding includes all fields in the attestation structure,
        /// ensuring a unique hash representing the data.
        ///
        /// @param attestation The attestation data to encode.
        /// @return A bytes32 hash of the encoded attestation.
        fn encodeAttestation(self: @ContractState, attestation: Attestation) -> u256 {
            let mut encodeData: ByteArray = "";
            encodeData += utils::EthAddressToByteArray(attestation.recipient);
            encodeData += utils::U256ToByteArray(self.encodeRequest(attestation.request));
            encodeData += utils::U256ToByteArray(self.encodeResponse(attestation.reponseResolve));
            encodeData += attestation.data;
            encodeData += attestation.attConditions;
            encodeData += utils::U64ToByteArray(attestation.timestamp);
            encodeData += attestation.additionParams;

            return utils::reverse_u256(compute_keccak_byte_array(@encodeData));
        }

        /// @dev Encodes a network request into a bytes32 hash.
        ///
        /// The encoding includes the URL, headers, HTTP method, and body of the request.
        ///
        /// @param request The network request to encode.
        /// @return A bytes32 hash of the encoded network request.
        fn encodeRequest(self: @ContractState, request: AttNetworkRequest) -> u256 {
            let mut encodeData: ByteArray = "";
            encodeData += request.url;
            encodeData += request.header;
            encodeData += request.method;
            encodeData += request.body;

            return utils::reverse_u256(compute_keccak_byte_array(@encodeData));
        }

        ///  @dev Encodes a list of network response resolutions into a bytes32 hash.
        ///
        ///  This iterates through the response array and encodes each field, creating
        ///  a unique hash representing the full response data.
        ///
        ///  @param reponse The array of response resolutions to encode.
        ///  @return A bytes32 hash of the encoded response resolutions.
        fn encodeResponse(self: @ContractState, reponse: Array<AttNetworkResponseResolve>) -> u256 {
            let mut encodeData: ByteArray = "";
            for rep in reponse {
                encodeData += rep.keyName;
                encodeData += rep.parseType;
                encodeData += rep.parsePath;
            }

            return utils::reverse_u256(compute_keccak_byte_array(@encodeData));
        }

        /// @dev Verifies the validity of a given attestation.
        ///
        /// Requirements:
        /// - Attestation must contain valid signatures from attestors.
        /// - The data, request, and response must be consistent.
        /// - The attestation must not be expired based on its timestamp.
        ///
        /// @param attestation The attestation data to be verified.
        fn verifyAttestation(self: @ContractState, attestation: Attestation) {
            assert(attestation.signatures.len() == 1, 'Invalid signatures length');

            let signature = attestation.signatures.at(0);
            assert(signature.len() == 65, 'Invalid signature length');

            ///////////////////
            // let (r, s, v) = utils::split_signature(signature);
            let (r, s, v) = utils::split_signature2(signature);
            let signature = signature_from_vrs(v.into(), r, s);
            let msg_hash = self.encodeAttestation(attestation);
            let attestorAddr = utils::ecrecover_to_eth_address(msg_hash, signature).unwrap();
            ///////////////////

            let mut i = 0;
            let length = self._attestors.len();
            for j in 0..length {
                if self._attestors.at(j).read().attestorAddr == attestorAddr {
                    break;
                }
                i += 1;
            }
            assert(i < length, 'Invalid signature');
        }
    }
}
