// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {CommandStruct} from "../structs/CommandStruct.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IEntityNFT} from "../interfaces/IEntityNFT.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";
import {SetRegistryWrapper} from "./SetRegistryWrapper.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {TigerHuntAccessManager} from "../access/TigerHuntAccessManager.sol";

contract CommandRegistry is AccessManaged {
    bytes32 public constant SET_KEY_COMMAND_IDS =
        keccak256("SET_KEY_COMMAND_IDS");

    bytes32 public constant SET_KEY_ENTITY_PAIR_IDS =
        keccak256("SET_KEY_ENTITY_PAIR_IDS");

    bytes32 public constant PARTIAL_SET_KEY_PAIR_ALLOWED_COMMANDS =
        keccak256("PARTIAL_SET_KEY_PAIR_ALLOWED_COMMANDS");

    SetRegistryWrapper private immutable _sets;

    // Mapping from command ID to command definition
    mapping(bytes32 commandId => CommandStruct command) private _commands;

    error CommandNotRegistered(bytes32 commandId);
    event CommandRegistered(bytes32 commandId);
    event CommandAllowed(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    );
    event CommandDisabled(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    );

    constructor(
        SetRegistryWrapper sets,
        address accessManager
    ) AccessManaged(accessManager) {
        _sets = sets;
    }

    // Register a new command
    function registerCommand(
        CommandStruct calldata command
    ) external restricted {
        _commands[command.commandId] = command;
        _sets.typeBytes32().add(SET_KEY_COMMAND_IDS, command.commandId);
        emit CommandRegistered(command.commandId);
    }

    // Helper to create a key for source-target pair
    function getPairKey(
        IEntityNFT source,
        IEntityNFT target
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PARTIAL_SET_KEY_PAIR_ALLOWED_COMMANDS,
                    source,
                    target
                )
            );
    }

    // Helper to create a key for wildcard source
    function getWildcardSourceKey(
        IEntityNFT target
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PARTIAL_SET_KEY_PAIR_ALLOWED_COMMANDS,
                    IEntityNFT(address(0)),
                    target
                )
            );
    }

    // Helper to create a key for wildcard target
    function getWildcardTargetKey(
        IEntityNFT source
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PARTIAL_SET_KEY_PAIR_ALLOWED_COMMANDS,
                    source,
                    IEntityNFT(address(0))
                )
            );
    }

    // Allow an entity type to use a command on a target entity type
    // For wildcard source, set source to address(0)
    // For wildcard target, set target to address(0)
    function allowCommand(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    ) external restricted {
        // Revert if command is not registered
        if (!_sets.typeBytes32().contains(SET_KEY_COMMAND_IDS, commandId))
            revert CommandNotRegistered(commandId);

        // Add command ID to set of allowed commands for this pair, if not already present
        bytes32 pairKey = getPairKey(sourceEntityType, targetEntityType);
        _sets.typeBytes32().add(pairKey, commandId);

        emit CommandAllowed(sourceEntityType, targetEntityType, commandId);
    }

    function disableCommand(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    ) external restricted {
        // Remove command ID from set of allowed commands for this pair
        bytes32 pairKey = getPairKey(sourceEntityType, targetEntityType);
        _sets.typeBytes32().remove(pairKey, commandId);

        emit CommandDisabled(sourceEntityType, targetEntityType, commandId);
    }

    // Check if command is valid for source entity targeting target entity
    function canUseCommand(
        IEntityNFT sourceEntityType,
        IEntityNFT targetEntityType,
        bytes32 commandId
    ) external view returns (bool) {
        // Check specific source-target pair
        bytes32 pairKey = getPairKey(sourceEntityType, targetEntityType);
        bytes32 wildcardSourceKey = getWildcardSourceKey(targetEntityType);
        bytes32 wildcardTargetKey = getWildcardTargetKey(sourceEntityType);

        if (!_sets.typeBytes32().contains(SET_KEY_COMMAND_IDS, commandId))
            return false;

        if (_sets.typeBytes32().contains(pairKey, commandId)) return true;
        if (_sets.typeBytes32().contains(wildcardSourceKey, commandId))
            return true;
        if (_sets.typeBytes32().contains(wildcardTargetKey, commandId))
            return true;

        return false;
    }

    // Get command details
    function getCommand(
        bytes32 commandId
    ) external view returns (CommandStruct memory) {
        return _commands[commandId];
    }
}
