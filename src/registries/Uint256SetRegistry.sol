// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.29;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Uint256SetRegistry
 * @dev Implementation of ISetRegistry for uint256 type
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 */
contract Uint256SetRegistry {
    using EnumerableSet for EnumerableSet.UintSet;

    // Registry for uint256 sets - msg.sender => setId => set
    mapping(address owner => mapping(bytes32 setId => EnumerableSet.UintSet set))
        private _uint256Sets;

    // Events
    event AddUint256(bytes32 setId, uint256 number);
    event RemoveUint256(bytes32 setId, uint256 number);

    function add(bytes32 setId, uint256 number) external {
        if (!_uint256Sets[msg.sender][setId].contains(number)) {
            _uint256Sets[msg.sender][setId].add(number);
            emit AddUint256(setId, number);
        }
    }

    function addBatch(bytes32 setId, uint256[] calldata numbers) external {
        for (uint256 i; i < numbers.length; i++) {
            uint256 number = numbers[i];
            if (!_uint256Sets[msg.sender][setId].contains(number)) {
                _uint256Sets[msg.sender][setId].add(number);
                emit AddUint256(setId, number);
            }
        }
    }

    function remove(bytes32 setId, uint256 number) external {
        if (_uint256Sets[msg.sender][setId].contains(number)) {
            _uint256Sets[msg.sender][setId].remove(number);
            emit RemoveUint256(setId, number);
        }
    }

    function removeBatch(bytes32 setId, uint256[] calldata numbers) external {
        for (uint256 i; i < numbers.length; i++) {
            uint256 number = numbers[i];
            if (_uint256Sets[msg.sender][setId].contains(number)) {
                _uint256Sets[msg.sender][setId].remove(number);
                emit RemoveUint256(setId, number);
            }
        }
    }

    function contains(
        bytes32 setId,
        uint256 number
    ) external view returns (bool) {
        return _uint256Sets[msg.sender][setId].contains(number);
    }

    function length(bytes32 setId) external view returns (uint256) {
        return _uint256Sets[msg.sender][setId].length();
    }

    function at(
        bytes32 setId,
        uint256 index
    ) external view returns (uint256 number) {
        return _uint256Sets[msg.sender][setId].at(index);
    }

    function getAll(
        bytes32 setId
    ) external view returns (uint256[] memory numbers) {
        return _uint256Sets[msg.sender][setId].values();
    }
}
