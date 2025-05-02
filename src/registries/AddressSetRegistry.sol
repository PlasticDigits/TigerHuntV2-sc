// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title AddressSetRegistry
 * @dev Implementation of ISetRegistry for address type
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 */
contract AddressSetRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Registry for address sets - msg.sender => setId => set
    mapping(address owner => mapping(bytes32 setId => EnumerableSet.AddressSet set))
        private _addressSets;

    // Events
    event AddAddress(bytes32 setId, address account);
    event RemoveAddress(bytes32 setId, address account);

    function add(bytes32 setId, address account) external {
        if (!_addressSets[msg.sender][setId].contains(account)) {
            _addressSets[msg.sender][setId].add(account);
            emit AddAddress(setId, account);
        }
    }

    function addBatch(bytes32 setId, address[] calldata accounts) external {
        for (uint256 i; i < accounts.length; i++) {
            address account = accounts[i];
            if (!_addressSets[msg.sender][setId].contains(account)) {
                _addressSets[msg.sender][setId].add(account);
                emit AddAddress(setId, account);
            }
        }
    }

    function remove(bytes32 setId, address account) external {
        if (_addressSets[msg.sender][setId].contains(account)) {
            _addressSets[msg.sender][setId].remove(account);
            emit RemoveAddress(setId, account);
        }
    }

    function removeBatch(bytes32 setId, address[] calldata accounts) external {
        for (uint256 i; i < accounts.length; i++) {
            address account = accounts[i];
            if (_addressSets[msg.sender][setId].contains(account)) {
                _addressSets[msg.sender][setId].remove(account);
                emit RemoveAddress(setId, account);
            }
        }
    }

    function contains(
        bytes32 setId,
        address account
    ) external view returns (bool) {
        return _addressSets[msg.sender][setId].contains(account);
    }

    function length(bytes32 setId) external view returns (uint256) {
        return _addressSets[msg.sender][setId].length();
    }

    function at(
        bytes32 setId,
        uint256 index
    ) external view returns (address account) {
        return _addressSets[msg.sender][setId].at(index);
    }

    function getAll(
        bytes32 setId
    ) external view returns (address[] memory accounts) {
        return _addressSets[msg.sender][setId].values();
    }
}
