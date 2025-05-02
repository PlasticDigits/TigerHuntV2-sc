// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";
import {TigerHuntAccessManager} from "../access/TigerHuntAccessManager.sol";

contract SpawnRegistry is AccessManaged {
    // Remove role constant as it's now defined in TigerHuntAccessManager
    // bytes32 public constant SPAWN_MANAGER_ROLE = keccak256("SPAWN_MANAGER_ROLE");

    IWorldRegistry public worldRegistry;

    // Mapping of world IDs to whether they are valid spawn points
    mapping(uint256 worldId => bool isValidSpawnWorld) public validSpawnWorlds;

    event SpawnRegistryInitialized(address worldRegistry);
    event SpawnWorldAdded(uint256 worldId);
    event SpawnWorldRemoved(uint256 worldId);

    constructor(address accessManager) AccessManaged(accessManager) {}

    function setDependencies(
        IWorldRegistry _worldRegistry
    ) external restricted {
        worldRegistry = _worldRegistry;
        emit SpawnRegistryInitialized(address(_worldRegistry));
    }

    function addValidSpawnWorld(uint256 worldId) external restricted {
        if (validSpawnWorlds[worldId]) revert RegistryUtils.AlreadyRegistered();

        validSpawnWorlds[worldId] = true;
        emit SpawnWorldAdded(worldId);
    }

    function removeValidSpawnWorld(uint256 worldId) external restricted {
        if (!validSpawnWorlds[worldId]) revert RegistryUtils.NotRegistered();

        validSpawnWorlds[worldId] = false;
        emit SpawnWorldRemoved(worldId);
    }
}
