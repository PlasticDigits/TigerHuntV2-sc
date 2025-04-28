// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IGameWorld} from "./IGameWorld.sol";
import {GameEntity} from "../structs/GameEntity.sol";

interface IWorldRegistry {
    event EntityWorldChanged(
        GameEntity indexed gameEntity,
        uint256 indexed oldWorldId,
        uint256 indexed newWorldId
    );

    event WorldUnregistered(uint256 worldId, IGameWorld world);
    event WorldRegistered(uint256 worldId, IGameWorld world);

    error UnauthorizedWorld();
    error EntityNotInWorld();
    error InvalidWorldTransition();

    function getEntityWorldId(
        GameEntity calldata gameEntity
    ) external view returns (uint256);
    function updateEntityWorld(
        GameEntity calldata gameEntity,
        uint256 targetWorldId
    ) external;
    function registerWorld(IGameWorld world) external;
    function isWorldRegistered(IGameWorld world) external view returns (bool);
    function getWorldId(IGameWorld world) external view returns (uint256);
}
