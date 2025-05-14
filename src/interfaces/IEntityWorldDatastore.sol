// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

interface IEntityWorldDatastore {
    event EntityWorldChanged(
        GameEntity indexed gameEntity,
        uint256 indexed oldWorldId,
        uint256 indexed newWorldId
    );

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256);

    function setEntityWorldId(
        GameEntity calldata gameEntity,
        uint256 worldId
    ) external;

    function getAreEntitiesInSameWorld(
        GameEntity calldata gameEntity1,
        GameEntity calldata gameEntity2
    ) external view returns (bool);
}
