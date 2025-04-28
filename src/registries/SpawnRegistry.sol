// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";
import {GameEntity} from "../structs/GameEntity.sol";

contract SpawnRegistry is AccessControlEnumerable {
    bytes32 public constant SPAWN_MANAGER_ROLE =
        keccak256("SPAWN_MANAGER_ROLE");

    IWorldRegistry public worldRegistry;

    // Mapping of world IDs to whether they are valid spawn points
    mapping(uint256 worldId => bool isValidSpawnWorld) public validSpawnWorlds;

    event SpawnRegistryInitialized(address worldRegistry);
    event SpawnWorldAdded(uint256 worldId);
    event SpawnWorldRemoved(uint256 worldId);
    event EntitySpawned(GameEntity gameEntity, uint256 worldId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SPAWN_MANAGER_ROLE, msg.sender);
    }

    function setWorldRegistry(
        IWorldRegistry _worldRegistry
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        worldRegistry = _worldRegistry;
        emit SpawnRegistryInitialized(address(_worldRegistry));
    }

    function addValidSpawnWorld(
        uint256 worldId
    ) external onlyRole(SPAWN_MANAGER_ROLE) {
        validSpawnWorlds[worldId] = true;
        emit SpawnWorldAdded(worldId);
    }

    function removeValidSpawnWorld(
        uint256 worldId
    ) external onlyRole(SPAWN_MANAGER_ROLE) {
        validSpawnWorlds[worldId] = false;
        emit SpawnWorldRemoved(worldId);
    }

    function spawnEntity(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external onlyRole(SPAWN_MANAGER_ROLE) {
        if (!validSpawnWorlds[targetWorldId])
            revert RegistryUtils.InvalidWorld();

        // Revert if the entity is already in a world
        if (worldRegistry.getEntityWorldId(gameEntity) != 0)
            revert RegistryUtils.EntityAlreadyInWorld();

        worldRegistry.updateEntityWorld(gameEntity, targetWorldId);

        emit EntitySpawned(gameEntity, targetWorldId);
    }
}
