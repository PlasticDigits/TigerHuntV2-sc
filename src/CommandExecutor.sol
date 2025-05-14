// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Entrypoint for playing the game, executes commands
pragma solidity ^0.8.23;

import {GameEntity} from "./structs/GameEntity.sol";
import {GameEntityUtils} from "./libraries/GameEntityUtils.sol";
import {CommandStruct} from "./structs/CommandStruct.sol";
import {CommandRegistry} from "./registries/CommandRegistry.sol";
import {IWorldRegistry} from "./interfaces/IWorldRegistry.sol";
import {IEntityNFT} from "./interfaces/IEntityNFT.sol";
import {ICmdImplSelf} from "./interfaces/ICommandImplementer.sol";
import {ICmdImplEntity} from "./interfaces/ICommandImplementer.sol";
import {ICmdImplWorld} from "./interfaces/ICommandImplementer.sol";
import {IEntityWorldDatastore} from "./interfaces/IEntityWorldDatastore.sol";

contract CommandExecutor {
    using GameEntityUtils for GameEntity;
    CommandRegistry public immutable COMMAND_REGISTRY;
    IWorldRegistry public immutable WORLD_REGISTRY;
    IEntityWorldDatastore public immutable ENTITY_WORLD_DATASTORE;

    error CommandNotUsableByEntity();
    error CommandOnCooldown();
    error EntityDurationLocked();
    error EntitiesNotInSameWorld();
    error EntitiesNotInSameTile();
    error BadCommandType();
    error NotOwner();
    error NotCorrectWorld();
    error CommandExecutionFailed();
    // Store last action time for cooldowns
    mapping(bytes32 actionKey => uint256 lastActionTime)
        private _lastActionTime;

    // Store GameEntity unlock time for duration commands
    mapping(bytes32 gameEntityKey => uint256 unlockTime) private _unlockTime;

    // Store allowed commands for a game entity
    mapping(bytes32 gameEntityKey => bytes32 allowedCommandsKey)
        private _allowedCommandsKey;

    constructor(
        CommandRegistry _commandRegistry,
        IWorldRegistry _worldRegistry,
        IEntityWorldDatastore _entityWorldDatastore
    ) {
        COMMAND_REGISTRY = _commandRegistry;
        WORLD_REGISTRY = _worldRegistry;
        ENTITY_WORLD_DATASTORE = _entityWorldDatastore;
    }

    function executeCommand(
        bytes32 commandId,
        GameEntity calldata sourceEntity,
        GameEntity calldata targetEntity,
        bytes calldata commandData
    ) external {
        // check sender is owner of sourceEntity
        if (sourceEntity.entityNFT.ownerOf(sourceEntity.entityId) != msg.sender)
            revert NotOwner();

        bytes32 sourceEntityKey = sourceEntity.getKey();
        bytes32 actionKey = getActionKey(commandId, sourceEntityKey);
        //Check if entity is locked due to duration command
        if (isEntityDurationLocked(sourceEntityKey))
            revert EntityDurationLocked();

        // Get command details
        CommandStruct memory command = COMMAND_REGISTRY.getCommand(commandId);

        // Check entity can use this command
        if (
            !COMMAND_REGISTRY.canUseCommand(
                sourceEntity.entityNFT,
                targetEntity.entityNFT,
                commandId
            )
        ) revert CommandNotUsableByEntity();

        // Check cooldown
        if (isCommandOnCooldown(commandId, actionKey))
            revert CommandOnCooldown();

        // Update cooldown
        _lastActionTime[actionKey] = block.timestamp;
        // Update GameEntity last action time for duration commands
        if (command.duration > 0) {
            _unlockTime[sourceEntityKey] = block.timestamp + command.duration;
        } else {
            _unlockTime[sourceEntityKey] = 0;
        }

        // Check if target entity is empty - if so, its a world command
        if (targetEntity.entityNFT == IEntityNFT(address(0))) {
            _executeWorldCommand(
                commandId,
                command.implementer,
                sourceEntity,
                commandData
            );
            // Check if source and target are identical - if so, its a self command
        } else if (
            sourceEntity.entityNFT == targetEntity.entityNFT &&
            sourceEntity.entityId == targetEntity.entityId
        ) {
            _executeSelfCommand(
                commandId,
                command.implementer,
                sourceEntity,
                commandData
            );
        } else {
            // Its an entity targeting a second entity,
            // such as a player attacking a player, or a player using a structure.
            _executeEntityCommand(
                commandId,
                command.implementer,
                sourceEntity,
                targetEntity,
                commandData
            );
        }
    }

    function getActionKey(
        bytes32 commandId,
        bytes32 entityKey
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(entityKey, commandId));
    }

    function isCommandOnCooldown(
        bytes32 commandId,
        bytes32 actionKey
    ) public view returns (bool) {
        CommandStruct memory command = COMMAND_REGISTRY.getCommand(commandId);
        return block.timestamp >= _lastActionTime[actionKey] + command.cooldown;
    }

    function isEntityDurationLocked(
        bytes32 sourceEntityKey
    ) public view returns (bool) {
        return block.timestamp < _unlockTime[sourceEntityKey];
    }

    function _executeWorldCommand(
        bytes32 commandId,
        ICmdImplWorld implementer,
        GameEntity calldata entity,
        bytes calldata commandData
    ) internal {
        implementer.executeWorldCommand(commandId, entity, commandData);
    }

    function _executeSelfCommand(
        bytes32 commandId,
        ICmdImplSelf implementer,
        GameEntity calldata entity,
        bytes calldata commandData
    ) internal {
        implementer.executeSelfCommand(commandId, entity, commandData);
    }

    function _executeEntityCommand(
        bytes32 commandId,
        ICmdImplEntity implementer,
        GameEntity calldata sourceEntity,
        GameEntity calldata targetEntity,
        bytes calldata commandData
    ) internal {
        // Check entities are in same world and tile
        if (
            !ENTITY_WORLD_DATASTORE.getAreEntitiesInSameWorld(
                sourceEntity,
                targetEntity
            )
        ) revert EntitiesNotInSameWorld();
        if (
            !WORLD_REGISTRY
                .getWorldFromWorldId(
                    ENTITY_WORLD_DATASTORE.getEntityWorldId(sourceEntity)
                )
                .areEntitiesInSameTile(sourceEntity, targetEntity)
        ) revert EntitiesNotInSameTile();

        // Execute the command by calling the implementer
        implementer.executeEntityCommand(
            commandId,
            sourceEntity,
            targetEntity,
            commandData
        );
    }
}
