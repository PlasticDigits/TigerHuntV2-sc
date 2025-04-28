// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {IGameWorld} from "../interfaces/IGameWorld.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";
import {SpawnRegistry} from "./SpawnRegistry.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {GameEntityUtils} from "../libraries/GameEntityUtils.sol";

contract WorldRegistry is IWorldRegistry, AccessControlEnumerable {
    using GameEntityUtils for GameEntity;

    bytes32 public constant WORLD_MANAGER_ROLE =
        keccak256("WORLD_MANAGER_ROLE");

    mapping(bytes32 entityKey => uint256 worldId) private _entityWorldIds;
    mapping(IGameWorld worldAddress => uint256 worldId) private _worldIds;
    mapping(uint256 worldId => IGameWorld worldAddress) private _worldIdToWorld;
    uint256 private _nextWorldId = 1;

    event SpawnRegistrySet(SpawnRegistry spawnRegistry);
    SpawnRegistry public spawnRegistry;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WORLD_MANAGER_ROLE, msg.sender);
    }

    function setSpawnRegistry(
        SpawnRegistry _spawnRegistry
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        spawnRegistry = _spawnRegistry;
        emit SpawnRegistrySet(spawnRegistry);
    }

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256) {
        return _entityWorldIds[gameEntity.getKey()];
    }

    function moveEntity(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external {
        updateEntityWorld(gameEntity, targetWorldId);
    }

    function updateEntityWorld(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) public {
        // If the target world is not registered, revert
        if (_worldIdToWorld[targetWorldId] == IGameWorld(address(0)))
            revert RegistryUtils.InvalidWorld();

        uint256 currentWorldId = _entityWorldIds[gameEntity.getKey()];

        // If entity is spawning (currentWorldId == 0), only allow SpawnRegistry
        if (currentWorldId == 0) {
            if (msg.sender != address(spawnRegistry))
                revert RegistryUtils.Unauthorized();
        } else {
            // For existing entities, only allow transfer from current world
            if (currentWorldId != _worldIds[IGameWorld(msg.sender)])
                revert RegistryUtils.Unauthorized();
        }

        _entityWorldIds[gameEntity.getKey()] = targetWorldId;
        emit EntityWorldChanged(gameEntity, currentWorldId, targetWorldId);
    }

    function registerWorld(
        IGameWorld world
    ) external onlyRole(WORLD_MANAGER_ROLE) {
        if (_worldIds[world] != 0) revert RegistryUtils.AlreadyRegistered();

        uint256 worldId = _nextWorldId++;
        _worldIds[world] = worldId;
        _worldIdToWorld[worldId] = world;
        emit WorldRegistered(worldId, world);
    }

    function unregisterWorld(
        IGameWorld world
    ) external onlyRole(WORLD_MANAGER_ROLE) {
        if (_worldIds[world] == 0) revert RegistryUtils.NotRegistered();

        uint256 worldId = _worldIds[world];
        delete _worldIds[world];
        delete _worldIdToWorld[worldId];
        emit WorldUnregistered(worldId, world);
    }

    function isWorldRegistered(IGameWorld world) external view returns (bool) {
        return _worldIds[world] != 0;
    }

    function getWorldId(IGameWorld world) external view returns (uint256) {
        return _worldIds[world];
    }

    function getWorldFromWorldId(
        uint256 worldId
    ) external view returns (IGameWorld) {
        return _worldIdToWorld[worldId];
    }
}
