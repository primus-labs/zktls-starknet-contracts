use core::integer;
use starknet::EthAddress;
use starknet::eth_signature::public_key_point_to_eth_address;
use starknet::secp256_trait::{Signature, is_signature_entry_valid, recover_public_key};
use starknet::secp256k1::Secp256k1Point;

pub fn reverse_u256(v: u256) -> u256 {
    let low = integer::u128_byte_reverse(v.low);
    let high = integer::u128_byte_reverse(v.high);
    u256 { low: high, high: low }
}

fn _one_shift_left_bytes_u128(n_bytes: usize) -> u128 {
    match n_bytes {
        0 => 0x1,
        1 => 0x100,
        2 => 0x10000,
        3 => 0x1000000,
        4 => 0x100000000,
        5 => 0x10000000000,
        6 => 0x1000000000000,
        7 => 0x100000000000000,
        8 => 0x10000000000000000,
        9 => 0x1000000000000000000,
        10 => 0x100000000000000000000,
        11 => 0x10000000000000000000000,
        12 => 0x1000000000000000000000000,
        13 => 0x100000000000000000000000000,
        14 => 0x10000000000000000000000000000,
        15 => 0x1000000000000000000000000000000,
        _ => 0 // never enter here
    }
}

fn hex_char_to_val(c: u8) -> u8 {
    if c >= '0' && c <= '9' {
        c - '0'
    } else if c >= 'a' && c <= 'f' {
        c - 'a' + 10
    } else if c >= 'A' && c <= 'F' {
        c - 'A' + 10
    } else {
        0 // never enter here
    }
}

/// no 0x prefix
/// hex.len = 2*N, the out.len is N
pub fn hex_to_bytes(hexstring: ByteArray) -> ByteArray {
    assert(hexstring.len() % 2 == 0, 'Invalid hexstring length');

    let mut i = 0;
    let mut out: ByteArray = "";
    while i != hexstring.len() {
        let mut v = hex_char_to_val(hexstring.at(i).unwrap()) * 16;
        i += 1;

        v = v + hex_char_to_val(hexstring.at(i).unwrap());
        i += 1;

        out.append_byte(v);
    }
    out
}
pub fn hex_to_bytes2(hexstring: ByteArray) -> Array<u8> {
    assert(hexstring.len() % 2 == 0, 'Invalid hexstring length');

    let mut i = 0;
    let mut out = array![];
    while i != hexstring.len() {
        let mut v = hex_char_to_val(hexstring.at(i).unwrap()) * 16;
        i += 1;

        v = v + hex_char_to_val(hexstring.at(i).unwrap());
        i += 1;

        out.append(v);
    }
    out
}

/// split rHrLsHsLv to rsv
pub fn split_signature2(signature: @Array<u8>) -> (u256, u256, u8) {
    assert(signature.len() == 65, 'Invalid signature length');

    // r
    let mut low: u128 = 0;
    let mut high: u128 = 0;
    for i in 0..32_u32 {
        let v: u128 = (*signature[i]).into();
        let k = 15 - (i % 16);
        if i % 32 < 16 {
            high = high + v * _one_shift_left_bytes_u128(k);
        } else if i % 32 < 32 {
            low = low + v * _one_shift_left_bytes_u128(k);
        }
    }
    let r = u256 { low, high };

    // s
    low = 0;
    high = 0;
    for i in 32..64_u32 {
        let v: u128 = (*signature[i]).into();
        let k = 15 - (i % 16);
        if i % 32 < 16 {
            high = high + v * _one_shift_left_bytes_u128(k);
        } else if i % 32 < 32 {
            low = low + v * _one_shift_left_bytes_u128(k);
        }
    }
    let s = u256 { low, high };

    // v
    let v: u8 = (*signature[64]).into();

    return (r, s, v);
}

/// split rHrLsHsLv to rsv
pub fn split_signature(signature: @ByteArray) -> (u256, u256, u8) {
    assert(signature.len() == 65, 'Invalid signature length');

    // r
    let mut low: u128 = 0;
    let mut high: u128 = 0;
    for i in 0..32_u32 {
        let v: u128 = signature[i].into();
        let k = 15 - (i % 16);
        if i % 32 < 16 {
            high = high + v * _one_shift_left_bytes_u128(k);
        } else if i % 32 < 32 {
            low = low + v * _one_shift_left_bytes_u128(k);
        }
    }
    let r = u256 { low, high };

    // s
    low = 0;
    high = 0;
    for i in 32..64_u32 {
        let v: u128 = signature[i].into();
        let k = 15 - (i % 16);
        if i % 32 < 16 {
            high = high + v * _one_shift_left_bytes_u128(k);
        } else if i % 32 < 32 {
            low = low + v * _one_shift_left_bytes_u128(k);
        }
    }
    let s = u256 { low, high };

    // v
    let v: u8 = signature[64].into();

    return (r, s, v);
}

pub fn EthAddressToByteArray(v: EthAddress) -> ByteArray {
    let mut encodeData: ByteArray = "";
    encodeData.append_word(v.into(), 20);
    return encodeData;
}

pub fn U64ToByteArray(v: u64) -> ByteArray {
    let mut encodeData: ByteArray = "";
    encodeData.append_word(v.into(), 8);
    return encodeData;
}

pub fn U256ToByteArray(v: u256) -> ByteArray {
    let mut encodeData: ByteArray = "";
    encodeData.append_word(v.high.into(), 16);
    encodeData.append_word(v.low.into(), 16);
    return encodeData;
}


pub fn ecrecover_to_eth_address(
    msg_hash: u256, signature: Signature,
) -> Result<EthAddress, felt252> {
    if !is_signature_entry_valid::<Secp256k1Point>(signature.r) {
        return Err('Signature out of range');
    }
    if !is_signature_entry_valid::<Secp256k1Point>(signature.s) {
        return Err('Signature out of range');
    }

    let public_key_point = recover_public_key::<Secp256k1Point>(:msg_hash, :signature).unwrap();
    let calculated_eth_address = public_key_point_to_eth_address(:public_key_point);

    Ok(calculated_eth_address)
}

pub fn is_eth_signature_valid(
    msg_hash: u256, signature: Signature, eth_address: EthAddress,
) -> Result<(), felt252> {
    if !is_signature_entry_valid::<Secp256k1Point>(signature.r) {
        return Err('Signature out of range');
    }
    if !is_signature_entry_valid::<Secp256k1Point>(signature.s) {
        return Err('Signature out of range');
    }

    let public_key_point = recover_public_key::<Secp256k1Point>(:msg_hash, :signature).unwrap();
    let calculated_eth_address = public_key_point_to_eth_address(:public_key_point);
    if eth_address != calculated_eth_address {
        return Err('Invalid signature');
    }
    Ok(())
}
