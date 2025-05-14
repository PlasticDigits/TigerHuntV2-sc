// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IEntityWorldReducer} from "../interfaces/IEntityWorldReducer.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {GameEntityUtils} from "../libraries/GameEntityUtils.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";
import {IGameWorld} from "../interfaces/IGameWorld.sol";
import {SpawnRegistry} from "./SpawnRegistry.sol";
import {IEntityWorldDatastore} from "../interfaces/IEntityWorldDatastore.sol";

contract EntityWorldReducer is IEntityWorldReducer, AccessManaged {
    using GameEntityUtils for GameEntity;

    IWorldRegistry public worldRegistry;
    SpawnRegistry public spawnRegistry;
    IEntityWorldDatastore public entityWorldDatastore;

    event DependenciesSet(
        IWorldRegistry worldRegistry,
        SpawnRegistry spawnRegistry,
        IEntityWorldDatastore entityWorldDatastore
    );

    constructor(address accessManager) AccessManaged(accessManager) {}

    function setDependencies(
        IWorldRegistry _worldRegistry,
        SpawnRegistry _spawnRegistry,
        IEntityWorldDatastore _entityWorldDatastore
    ) external restricted {
        worldRegistry = _worldRegistry;
        spawnRegistry = _spawnRegistry;
        entityWorldDatastore = _entityWorldDatastore;
        emit DependenciesSet(
            worldRegistry,
            spawnRegistry,
            entityWorldDatastore
        );
    }

    function moveEntityBetweenWorlds(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external {
        // If the target world is not registered, revert
        // Unless it is 0, which means this is a despawn
        if (
            targetWorldId != 0 &&
            worldRegistry.getWorldFromWorldId(targetWorldId) ==
            IGameWorld(address(0))
        ) revert InvalidWorld();

        uint256 currentWorldId = entityWorldDatastore.getEntityWorldId(
            gameEntity
        );

        // Only allow spawning through spawnEntity
        if (currentWorldId == 0) revert EntityNotInWorld();

        // Only allow the current world to update the game entity's world
        if (currentWorldId != worldRegistry.getWorldId(IGameWorld(msg.sender)))
            revert Unauthorized();

        // Update entity world in datastore
        entityWorldDatastore.setEntityWorldId(gameEntity, targetWorldId);
    }

    function spawnEntity(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external restricted {
        // Check if the target world is a valid spawn point
        if (!spawnRegistry.validSpawnWorlds(targetWorldId))
            revert InvalidWorld();

        // Check if entity is already in a world
        if (entityWorldDatastore.getEntityWorldId(gameEntity) != 0)
            revert EntityAlreadyInWorld();

        // Check if the targetWorld is the calling contract
        if (worldRegistry.getWorldId(IGameWorld(msg.sender)) != targetWorldId)
            revert Unauthorized();

        // Update entity world in datastore
        entityWorldDatastore.setEntityWorldId(gameEntity, targetWorldId);
    }
}
