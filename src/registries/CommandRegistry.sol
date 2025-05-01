// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {CommandStruct} from "../structs/CommandStruct.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";

contract CommandRegistry is AccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using RegistryUtils for mapping(IEntityNFT => EnumerableSet.Bytes32Set);

    bytes32 public constant COMMAND_MANAGER_ROLE =
        keccak256("COMMAND_MANAGER_ROLE");

    // Mapping from command ID to command definition
    mapping(bytes32 commandId => CommandStruct command) private _commands;

    // Mapping from source+target entity type pair to allowed commands
    mapping(bytes32 sourceTargetPair => EnumerableSet.Bytes32Set commandIds)
        private _pairAllowedCommands;

    event CommandRegistered(bytes32 commandId);
    event CommandAllowed(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    );

    // Register a new command
    function registerCommand(
        CommandStruct calldata command
    ) external onlyRole(COMMAND_MANAGER_ROLE) {
        _commands[command.commandId] = command;
        emit CommandRegistered(command.commandId);
    }

    // Helper to create a key for source-target pair
    function _getPairKey(
        IEntityNFT source,
        IEntityNFT target
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(source, target));
    }

    // Helper to create a key for wildcard source
    function _getWildcardSourceKey(
        IEntityNFT target
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(IEntityNFT(address(0)), target));
    }

    // Helper to create a key for wildcard target
    function _getWildcardTargetKey(
        IEntityNFT source
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(source, IEntityNFT(address(0))));
    }

    // Allow an entity type to use a command on a target entity type
    function allowCommand(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    ) external onlyRole(COMMAND_MANAGER_ROLE) {
        require(
            _commands[commandId].commandId == commandId,
            "Command not registered"
        );

        bytes32 pairKey = _getPairKey(sourceEntityType, targetEntityType);
        _pairAllowedCommands[pairKey].add(commandId);

        emit CommandAllowed(sourceEntityType, targetEntityType, commandId);
    }

    // Check if command is valid for source entity targeting target entity
    function canUseCommand(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    ) external view returns (bool) {
        // Check specific source-target pair
        bytes32 pairKey = _getPairKey(sourceEntityType, targetEntityType);
        bytes32 wildcardSourceKey = _getWildcardSourceKey(targetEntityType);
        bytes32 wildcardTargetKey = _getWildcardTargetKey(sourceEntityType);

        if (_pairAllowedCommands[pairKey].contains(commandId)) return true;
        if (_pairAllowedCommands[wildcardSourceKey].contains(commandId))
            return true;
        if (_pairAllowedCommands[wildcardTargetKey].contains(commandId))
            return true;

        return false;
    }

    function getAllowedCommands(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType
    ) external view returns (bytes32[] memory) {
        bytes32 pairKey = _getPairKey(sourceEntityType, targetEntityType);
        bytes32 wildcardSourceKey = _getWildcardSourceKey(targetEntityType);
        bytes32 wildcardTargetKey = _getWildcardTargetKey(sourceEntityType);

        bytes32[] memory allowedCommands = new bytes32[](
            _pairAllowedCommands[pairKey].length() +
                _pairAllowedCommands[wildcardSourceKey].length() +
                _pairAllowedCommands[wildcardTargetKey].length()
        );

        uint256 index = 0;
        for (uint256 i = 0; i < _pairAllowedCommands[pairKey].length(); i++) {
            allowedCommands[index++] = _pairAllowedCommands[pairKey].at(i);
        }
        for (
            uint256 i = 0;
            i < _pairAllowedCommands[wildcardSourceKey].length();
            i++
        ) {
            allowedCommands[index++] = _pairAllowedCommands[wildcardSourceKey]
                .at(i);
        }
        for (
            uint256 i = 0;
            i < _pairAllowedCommands[wildcardTargetKey].length();
            i++
        ) {
            allowedCommands[index++] = _pairAllowedCommands[wildcardTargetKey]
                .at(i);
        }

        return allowedCommands;
    }

    // Get command details
    function getCommand(
        bytes32 commandId
    ) external view returns (CommandStruct memory) {
        return _commands[commandId];
    }
}
