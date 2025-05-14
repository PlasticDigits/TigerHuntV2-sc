// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IEntityWorldDatastore} from "../interfaces/IEntityWorldDatastore.sol";
import {GameEntity} from "../structs/GameEntity.sol";
import {GameEntityUtils} from "../libraries/GameEntityUtils.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {TigerHuntAccessManager} from "../access/TigerHuntAccessManager.sol";

contract EntityWorldDatastore is IEntityWorldDatastore, AccessManaged {
    using GameEntityUtils for GameEntity;

    mapping(bytes32 entityKey => uint256 worldId) private _entityWorldIds;

    constructor(address accessManager) AccessManaged(accessManager) {}

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256) {
        return _entityWorldIds[gameEntity.getKey()];
    }

    function setEntityWorldId(
        GameEntity calldata gameEntity,
        uint256 worldId
    ) external restricted {
        bytes32 entityKey = gameEntity.getKey();
        uint256 oldWorldId = _entityWorldIds[entityKey];
        _entityWorldIds[entityKey] = worldId;
        emit EntityWorldChanged(gameEntity, oldWorldId, worldId);
    }

    function getAreEntitiesInSameWorld(
        GameEntity calldata gameEntity1,
        GameEntity calldata gameEntity2
    ) external view returns (bool) {
        return
            _entityWorldIds[gameEntity1.getKey()] ==
            _entityWorldIds[gameEntity2.getKey()];
    }
}
