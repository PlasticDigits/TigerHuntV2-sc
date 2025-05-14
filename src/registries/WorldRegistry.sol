// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IWorldRegistry} from "../interfaces/IWorldRegistry.sol";
import {IGameWorld} from "../interfaces/IGameWorld.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {RegistryUtils} from "../libraries/RegistryUtils.sol";

contract WorldRegistry is IWorldRegistry, AccessManaged {
    mapping(IGameWorld worldAddress => uint256 worldId) private _worldIds;
    mapping(uint256 worldId => IGameWorld worldAddress) private _worldIdToWorld;
    uint256 private _nextWorldId = 1;

    constructor(address accessManager) AccessManaged(accessManager) {}

    function registerWorld(IGameWorld world) external restricted {
        if (_worldIds[world] != 0) revert AlreadyRegistered();

        uint256 worldId = _nextWorldId++;
        _worldIds[world] = worldId;
        _worldIdToWorld[worldId] = world;
        emit WorldRegistered(worldId, world);
    }

    function unregisterWorld(IGameWorld world) external restricted {
        if (_worldIds[world] == 0) revert NotRegistered();

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
