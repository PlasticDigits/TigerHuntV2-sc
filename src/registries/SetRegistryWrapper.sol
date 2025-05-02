// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {AddressSetRegistry} from "./AddressSetRegistry.sol";
import {Bytes32SetRegistry} from "./Bytes32SetRegistry.sol";
import {Uint256SetRegistry} from "./Uint256SetRegistry.sol";

/**
 * @title MultiSetRegistry
 * @dev Makes it easier for contracts to find the right registry. Does not contain any logic or hold any permissions.
 *      This contract is not a registry, it is a wrapper around the other registries.
 */
contract SetRegistryWrapper {
    AddressSetRegistry public typeAddress;
    Bytes32SetRegistry public typeBytes32;
    Uint256SetRegistry public typeUint256;

    constructor() {
        typeAddress = new AddressSetRegistry();
        typeBytes32 = new Bytes32SetRegistry();
        typeUint256 = new Uint256SetRegistry();
    }
}
