// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Bytes32SetRegistry
 * @dev Implementation of ISetRegistry for bytes32 type
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 */
contract Bytes32SetRegistry {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // Registry for bytes32 sets - msg.sender => setId => set
    mapping(address owner => mapping(bytes32 setId => EnumerableSet.Bytes32Set set))
        private _bytes32Sets;

    // Events
    event AddBytes32(bytes32 setId, bytes32 data);
    event RemoveBytes32(bytes32 setId, bytes32 data);

    function add(bytes32 setId, bytes32 item) external {
        if (!_bytes32Sets[msg.sender][setId].contains(item)) {
            _bytes32Sets[msg.sender][setId].add(item);
            emit AddBytes32(setId, item);
        }
    }

    function addBatch(bytes32 setId, bytes32[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            bytes32 item = items[i];
            if (!_bytes32Sets[msg.sender][setId].contains(item)) {
                _bytes32Sets[msg.sender][setId].add(item);
                emit AddBytes32(setId, item);
            }
        }
    }

    function remove(bytes32 setId, bytes32 item) external {
        if (_bytes32Sets[msg.sender][setId].contains(item)) {
            _bytes32Sets[msg.sender][setId].remove(item);
            emit RemoveBytes32(setId, item);
        }
    }

    function removeBatch(bytes32 setId, bytes32[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            bytes32 item = items[i];
            if (_bytes32Sets[msg.sender][setId].contains(item)) {
                _bytes32Sets[msg.sender][setId].remove(item);
                emit RemoveBytes32(setId, item);
            }
        }
    }

    function contains(
        bytes32 setId,
        bytes32 item
    ) external view returns (bool) {
        return _bytes32Sets[msg.sender][setId].contains(item);
    }

    function length(bytes32 setId) external view returns (uint256) {
        return _bytes32Sets[msg.sender][setId].length();
    }

    function at(
        bytes32 setId,
        uint256 index
    ) external view returns (bytes32 item) {
        return _bytes32Sets[msg.sender][setId].at(index);
    }

    function getAll(
        bytes32 setId
    ) external view returns (bytes32[] memory items) {
        return _bytes32Sets[msg.sender][setId].values();
    }
}
